package services

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os/exec"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

type CheckerService struct {
	logger     *logrus.Logger
	ffprobeBin string
	timeout    time.Duration
	httpClient *http.Client
}

type StreamCheckResult struct {
	StreamID       int
	IsWorking      bool
	ResponseTimeMs int
	VideoCodec     *string
	AudioCodec     *string
	Resolution     *string
	Error          string
}

type CheckResult struct {
	ChannelID  string
	IsWorking  bool
	VideoCodec *string
	AudioCodec *string
	Resolution *string
	Error      string
}

type ffprobeOutput struct {
	Streams []ffprobeStream `json:"streams"`
}

type ffprobeStream struct {
	CodecType string `json:"codec_type"`
	CodecName string `json:"codec_name"`
	Width     int    `json:"width"`
	Height    int    `json:"height"`
}

func NewCheckerService(logger *logrus.Logger, ffprobeBin string, timeout time.Duration) *CheckerService {
	return &CheckerService{
		logger:     logger,
		ffprobeBin: ffprobeBin,
		timeout:    timeout,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if len(via) >= 3 {
					return fmt.Errorf("too many redirects")
				}
				return nil
			},
		},
	}
}

func (s *CheckerService) CheckStreamFull(ctx context.Context, streamID int, streamURL string) *StreamCheckResult {
	result := &StreamCheckResult{StreamID: streamID}
	start := time.Now()

	if !s.checkTCP(streamURL) {
		result.IsWorking = false
		result.Error = "tcp connect failed"
		result.ResponseTimeMs = int(time.Since(start).Milliseconds())
		return result
	}

	if strings.HasPrefix(streamURL, "http://") || strings.HasPrefix(streamURL, "https://") {
		if !s.checkHTTP(ctx, streamURL) {
			result.IsWorking = false
			result.Error = "http check failed"
			result.ResponseTimeMs = int(time.Since(start).Milliseconds())
			return result
		}
	}

	result.ResponseTimeMs = int(time.Since(start).Milliseconds())

	probeResult := s.probeStream(ctx, streamURL)
	if probeResult == nil {
		result.IsWorking = false
		result.Error = "ffprobe failed"
		return result
	}

	result.IsWorking = true
	result.VideoCodec = probeResult.VideoCodec
	result.AudioCodec = probeResult.AudioCodec
	result.Resolution = probeResult.Resolution
	return result
}

func (s *CheckerService) checkTCP(streamURL string) bool {
	u, err := url.Parse(streamURL)
	if err != nil {
		return false
	}

	host := u.Hostname()
	port := u.Port()
	if port == "" {
		switch u.Scheme {
		case "https":
			port = "443"
		case "rtsp":
			port = "554"
		case "rtmp":
			port = "1935"
		default:
			port = "80"
		}
	}

	conn, err := net.DialTimeout("tcp", net.JoinHostPort(host, port), 3*time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

func (s *CheckerService) checkHTTP(ctx context.Context, streamURL string) bool {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodHead, streamURL, nil)
	if err != nil {
		return false
	}
	req.Header.Set("User-Agent", "Mozilla/5.0")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		req.Method = http.MethodGet
		resp, err = s.httpClient.Do(req)
		if err != nil {
			return false
		}
	}
	defer resp.Body.Close()

	return resp.StatusCode >= 200 && resp.StatusCode < 400
}

type probeResult struct {
	VideoCodec *string
	AudioCodec *string
	Resolution *string
}

func (s *CheckerService) probeStream(ctx context.Context, streamURL string) *probeResult {
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, s.ffprobeBin,
		"-v", "quiet",
		"-print_format", "json",
		"-show_streams",
		"-timeout", "5000000",
		"-analyzeduration", "2000000",
		"-probesize", "1048576",
		streamURL,
	)

	output, err := cmd.Output()
	if err != nil {
		return nil
	}

	var probe ffprobeOutput
	if err := json.Unmarshal(output, &probe); err != nil {
		return nil
	}

	if len(probe.Streams) == 0 {
		return nil
	}

	r := &probeResult{}
	for _, stream := range probe.Streams {
		switch stream.CodecType {
		case "video":
			codec := stream.CodecName
			r.VideoCodec = &codec
			if stream.Width > 0 && stream.Height > 0 {
				res := fmt.Sprintf("%dx%d", stream.Width, stream.Height)
				r.Resolution = &res
			}
		case "audio":
			codec := stream.CodecName
			r.AudioCodec = &codec
		}
	}
	return r
}

func (s *CheckerService) CheckChannelFast(ctx context.Context, streamURL string) bool {
	if !s.checkTCP(streamURL) {
		return false
	}

	if strings.HasPrefix(streamURL, "http://") || strings.HasPrefix(streamURL, "https://") {
		if !s.checkHTTP(ctx, streamURL) {
			return false
		}
	}

	return true
}

func (s *CheckerService) CheckChannel(ctx context.Context, channelID, streamURL string) *CheckResult {
	result := &CheckResult{ChannelID: channelID}

	probe := s.probeStream(ctx, streamURL)
	if probe == nil {
		result.IsWorking = false
		result.Error = "probe failed"
		return result
	}

	result.IsWorking = true
	result.VideoCodec = probe.VideoCodec
	result.AudioCodec = probe.AudioCodec
	result.Resolution = probe.Resolution
	return result
}

func (s *CheckerService) GetStreamInfo(ctx context.Context, streamURL string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, s.ffprobeBin,
		"-v", "quiet",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		"-timeout", fmt.Sprintf("%d", s.timeout.Microseconds()),
		streamURL,
	)

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}
