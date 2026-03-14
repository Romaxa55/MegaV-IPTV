package services

import (
	"compress/gzip"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode"

	"github.com/romaxa55/iptv-parser/internal/models"
	"github.com/sirupsen/logrus"
)

type EPGService struct {
	logger *logrus.Logger
	client *http.Client
}

func NewEPGService(logger *logrus.Logger) *EPGService {
	return &EPGService{
		logger: logger,
		client: &http.Client{Timeout: 120 * time.Second},
	}
}

// XMLTV structures
type xmlTV struct {
	XMLName    xml.Name      `xml:"tv"`
	Channels   []xmlChannel  `xml:"channel"`
	Programmes []xmlProgram  `xml:"programme"`
}

type xmlChannel struct {
	ID          string         `xml:"id,attr"`
	DisplayName []xmlLangValue `xml:"display-name"`
	Icon        []xmlIcon      `xml:"icon"`
}

type xmlProgram struct {
	Start   string         `xml:"start,attr"`
	Stop    string         `xml:"stop,attr"`
	Channel string         `xml:"channel,attr"`
	Title   []xmlLangValue `xml:"title"`
	Desc    []xmlLangValue `xml:"desc"`
	Category []xmlLangValue `xml:"category"`
	Icon    []xmlIcon      `xml:"icon"`
}

type xmlLangValue struct {
	Lang  string `xml:"lang,attr"`
	Value string `xml:",chardata"`
}

type xmlIcon struct {
	Src string `xml:"src,attr"`
}

type EPGData struct {
	Channels     map[string][]string // epgID -> all display names
	Programs     []*models.EpgProgram
}

func (s *EPGService) FetchAndParse(epgURL string) (*EPGData, error) {
	s.logger.Infof("Fetching EPG: %s", epgURL)

	resp, err := s.client.Get(epgURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch EPG: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var reader io.Reader = resp.Body

	if strings.HasSuffix(epgURL, ".gz") || resp.Header.Get("Content-Encoding") == "gzip" {
		gzReader, err := gzip.NewReader(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to create gzip reader: %w", err)
		}
		defer gzReader.Close()
		reader = gzReader
	}

	return s.Parse(reader)
}

func (s *EPGService) Parse(reader io.Reader) (*EPGData, error) {
	var tv xmlTV
	decoder := xml.NewDecoder(reader)
	decoder.Strict = false
	decoder.CharsetReader = func(charset string, input io.Reader) (io.Reader, error) {
		return input, nil
	}

	if err := decoder.Decode(&tv); err != nil {
		return nil, fmt.Errorf("failed to decode XMLTV: %w", err)
	}

	data := &EPGData{
		Channels: make(map[string][]string),
	}

	for _, ch := range tv.Channels {
		var names []string
		for _, dn := range ch.DisplayName {
			if dn.Value != "" {
				names = append(names, dn.Value)
			}
		}
		if len(names) > 0 {
			data.Channels[ch.ID] = names
		}
	}

	for _, prog := range tv.Programmes {
		start, err := parseXMLTVTime(prog.Start)
		if err != nil {
			continue
		}
		end, err := parseXMLTVTime(prog.Stop)
		if err != nil {
			continue
		}

		title := ""
		if len(prog.Title) > 0 {
			title = prog.Title[0].Value
		}
		if title == "" {
			continue
		}

		refChannelID, _, _ := ParseTvgIDFeed(prog.Channel)

		p := &models.EpgProgram{
			ChannelID:          prog.Channel,
			ReferenceChannelID: &refChannelID,
			Title:              title,
			StartTime:          start,
			EndTime:            end,
		}

		if len(prog.Desc) > 0 && prog.Desc[0].Value != "" {
			desc := prog.Desc[0].Value
			p.Description = &desc
		}
		if len(prog.Category) > 0 && prog.Category[0].Value != "" {
			cat := prog.Category[0].Value
			p.Category = &cat
		}
		if len(prog.Icon) > 0 && prog.Icon[0].Src != "" {
			icon := prog.Icon[0].Src
			p.Icon = &icon
		}
		if len(prog.Title) > 0 && prog.Title[0].Lang != "" {
			lang := prog.Title[0].Lang
			p.Lang = &lang
		}

		data.Programs = append(data.Programs, p)
	}

	s.logger.Infof("Parsed EPG: %d channels, %d programs", len(data.Channels), len(data.Programs))
	return data, nil
}

// SmartMatch maps EPG channel IDs to IPTV channel IDs.
// channelNames should include both name and altNames from reference_channels.
func (s *EPGService) SmartMatch(
	epgChannels map[string][]string,
	tvgIDMap map[string]string,
	channelNames map[string]string,
) map[string]string {
	result := make(map[string]string)

	normalizedDB := make(map[string]string, len(channelNames))
	for name, id := range channelNames {
		normalizedDB[normalizeName(name)] = id
	}

	for epgID, epgNames := range epgChannels {
		if channelID, ok := tvgIDMap[epgID]; ok {
			result[epgID] = channelID
			continue
		}

		matched := false
		for _, epgName := range epgNames {
			norm := normalizeName(epgName)
			if chID, ok := normalizedDB[norm]; ok {
				result[epgID] = chID
				matched = true
				break
			}
		}
		if matched {
			continue
		}

		bestScore := 0.0
		bestChannelID := ""
		for _, epgName := range epgNames {
			normalizedEPG := normalizeName(epgName)
			for normCh, chID := range normalizedDB {
				score := similarity(normalizedEPG, normCh)
				if score > bestScore && score >= 0.85 {
					bestScore = score
					bestChannelID = chID
				}
			}
			if bestChannelID != "" {
				break
			}
		}

		if bestChannelID != "" {
			result[epgID] = bestChannelID
		}
	}

	s.logger.Infof("Smart matched %d/%d EPG channels", len(result), len(epgChannels))
	return result
}

func normalizeName(name string) string {
	name = strings.ToLower(name)
	for _, suffix := range []string{" hd", " sd", " fhd", " uhd", " 4k", " (backup)", " (+2)"} {
		name = strings.TrimSuffix(name, suffix)
	}
	name = strings.Map(func(r rune) rune {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			return r
		}
		return ' '
	}, name)
	parts := strings.Fields(name)
	return strings.Join(parts, " ")
}

func similarity(a, b string) float64 {
	if a == b {
		return 1.0
	}
	if a == "" || b == "" {
		return 0.0
	}

	// Levenshtein-based similarity
	d := levenshtein(a, b)
	maxLen := len(a)
	if len(b) > maxLen {
		maxLen = len(b)
	}
	return 1.0 - float64(d)/float64(maxLen)
}

func levenshtein(a, b string) int {
	la, lb := len(a), len(b)
	if la == 0 {
		return lb
	}
	if lb == 0 {
		return la
	}

	prev := make([]int, lb+1)
	curr := make([]int, lb+1)

	for j := 0; j <= lb; j++ {
		prev[j] = j
	}

	for i := 1; i <= la; i++ {
		curr[0] = i
		for j := 1; j <= lb; j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			curr[j] = min(curr[j-1]+1, min(prev[j]+1, prev[j-1]+cost))
		}
		prev, curr = curr, prev
	}
	return prev[lb]
}

func parseXMLTVTime(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	formats := []string{
		"20060102150405 -0700",
		"20060102150405",
		"200601021504",
	}
	for _, f := range formats {
		if t, err := time.Parse(f, s); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("cannot parse XMLTV time: %s", s)
}

func GetDefaultEPGSources() []string {
	return []string{
		"http://epg.it999.ru/epg2.xml.gz",
		"http://programtv.ru/xmltv.xml.gz",
	}
}

// BuildEPGSourcesForCountries generates EPG source URLs based on countries
// that have streams in our database. Uses community XMLTV aggregators.
func BuildEPGSourcesForCountries(countries []string) []string {
	communityEPG := map[string][]string{
		"RU": {
			"http://epg.it999.ru/epg2.xml.gz",
			"http://programtv.ru/xmltv.xml.gz",
			"http://www.teleguide.info/download/new3/xmltv.xml.gz",
			"https://iptvx.one/epg/epg.xml.gz",
		},
		"US": {
			"https://i.mjh.nz/PlutoTV/us.xml.gz",
			"https://i.mjh.nz/SamsungTVPlus/us.xml.gz",
		},
		"UK": {
			"https://i.mjh.nz/PlutoTV/uk.xml.gz",
			"https://raw.githubusercontent.com/dp247/Freeview-EPG/master/epg.xml",
		},
		"DE": {
			"https://i.mjh.nz/PlutoTV/de.xml.gz",
		},
		"FR": {
			"https://i.mjh.nz/PlutoTV/fr.xml.gz",
		},
		"BR": {
			"https://i.mjh.nz/PlutoTV/br.xml.gz",
		},
		"IN": {
			"https://i.mjh.nz/SamsungTVPlus/in.xml.gz",
		},
	}

	seen := make(map[string]bool)
	var urls []string

	for _, country := range countries {
		if sources, ok := communityEPG[country]; ok {
			for _, u := range sources {
				if !seen[u] {
					seen[u] = true
					urls = append(urls, u)
				}
			}
		}
	}

	return urls
}
