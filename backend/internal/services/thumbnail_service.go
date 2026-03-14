package services

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/sirupsen/logrus"
)

type ThumbnailService struct {
	logger    *logrus.Logger
	ffmpegBin string
	outputDir string
	timeout   time.Duration
}

func NewThumbnailService(logger *logrus.Logger, ffmpegBin, outputDir string, timeout time.Duration) *ThumbnailService {
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		logger.Warnf("Failed to create thumbnail dir %s: %v", outputDir, err)
	}
	return &ThumbnailService{
		logger:    logger,
		ffmpegBin: ffmpegBin,
		outputDir: outputDir,
		timeout:   timeout,
	}
}

func (s *ThumbnailService) GenerateThumbnail(ctx context.Context, channelID, streamURL string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	outputPath := filepath.Join(s.outputDir, channelID+".jpg")

	cmd := exec.CommandContext(ctx, s.ffmpegBin,
		"-y",
		"-i", streamURL,
		"-ss", "2",
		"-frames:v", "1",
		"-vf", "scale=640:-1",
		"-q:v", "5",
		"-timeout", fmt.Sprintf("%d", s.timeout.Microseconds()),
		"-analyzeduration", "3000000",
		"-probesize", "2097152",
		outputPath,
	)

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("ffmpeg failed for %s: %w", channelID, err)
	}

	info, err := os.Stat(outputPath)
	if err != nil || info.Size() == 0 {
		os.Remove(outputPath)
		return "", fmt.Errorf("thumbnail file empty or missing for %s", channelID)
	}

	return outputPath, nil
}

func (s *ThumbnailService) GetThumbnailPath(channelID string) string {
	return filepath.Join(s.outputDir, channelID+".jpg")
}

func (s *ThumbnailService) ThumbnailExists(channelID string) bool {
	path := s.GetThumbnailPath(channelID)
	info, err := os.Stat(path)
	return err == nil && info.Size() > 0
}
