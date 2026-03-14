package services

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

type CheckerService struct {
	logger     *logrus.Logger
	ffprobeBin string
	timeout    time.Duration
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
	}
}

func (s *CheckerService) CheckChannel(ctx context.Context, channelID, url string) *CheckResult {
	result := &CheckResult{ChannelID: channelID}

	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, s.ffprobeBin,
		"-v", "quiet",
		"-print_format", "json",
		"-show_streams",
		"-timeout", fmt.Sprintf("%d", s.timeout.Microseconds()),
		"-analyzeduration", "3000000",
		"-probesize", "2097152",
		url,
	)

	output, err := cmd.Output()
	if err != nil {
		result.IsWorking = false
		result.Error = err.Error()
		return result
	}

	var probe ffprobeOutput
	if err := json.Unmarshal(output, &probe); err != nil {
		result.IsWorking = false
		result.Error = fmt.Sprintf("failed to parse ffprobe output: %v", err)
		return result
	}

	if len(probe.Streams) == 0 {
		result.IsWorking = false
		result.Error = "no streams found"
		return result
	}

	result.IsWorking = true

	for _, stream := range probe.Streams {
		switch stream.CodecType {
		case "video":
			codec := stream.CodecName
			result.VideoCodec = &codec
			if stream.Width > 0 && stream.Height > 0 {
				res := fmt.Sprintf("%dx%d", stream.Width, stream.Height)
				result.Resolution = &res
			}
		case "audio":
			codec := stream.CodecName
			result.AudioCodec = &codec
		}
	}

	return result
}

func (s *CheckerService) CheckChannelFast(ctx context.Context, url string) bool {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, s.ffprobeBin,
		"-v", "quiet",
		"-timeout", "5000000",
		"-analyzeduration", "1000000",
		"-probesize", "500000",
		url,
	)

	err := cmd.Run()
	return err == nil
}

func (s *CheckerService) GetStreamInfo(ctx context.Context, url string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, s.ffprobeBin,
		"-v", "quiet",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		"-timeout", fmt.Sprintf("%d", s.timeout.Microseconds()),
		url,
	)

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}
