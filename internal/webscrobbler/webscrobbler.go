package webscrobbler

type Song struct {
	Parsed struct {
		Track               string `json:"track"`
		Artist              string `json:"artist"`
		AlbumArtist         string `json:"albumArtist"`
		Album               string `json:"album"`
		Duration            int    `json:"duration"`
		UniqueID            string `json:"uniqueID"`
		CurrentTime         int    `json:"currentTime"`
		IsPlaying           bool   `json:"isPlaying"`
		TrackArt            string `json:"trackArt"`
		IsPodcast           bool   `json:"isPodcast"`
		OriginURL           string `json:"originUrl"`
		IsScrobblingAllowed bool   `json:"isScrobblingAllowed"`
	} `json:"parsed"`
	Processed struct {
		Track       string `json:"track"`
		Artist      string `json:"artist"`
		AlbumArtist string `json:"albumArtist"`
		Duration    int    `json:"duration"`
	} `json:"processed"`
	NoRegex struct {
		Track       string `json:"track"`
		Artist      string `json:"artist"`
		AlbumArtist string `json:"albumArtist"`
		Duration    int    `json:"duration"`
	} `json:"noRegex"`
	Flags struct {
		IsScrobbled         bool `json:"isScrobbled"`
		IsCorrectedByUser   bool `json:"isCorrectedByUser"`
		IsRegexEditedByUser struct {
			Track       bool `json:"track"`
			Artist      bool `json:"artist"`
			Album       bool `json:"album"`
			AlbumArtist bool `json:"albumArtist"`
		} `json:"isRegexEditedByUser"`
		IsAlbumFetched    bool `json:"isAlbumFetched"`
		IsValid           bool `json:"isValid"`
		IsMarkedAsPlaying bool `json:"isMarkedAsPlaying"`
		IsSkipped         bool `json:"isSkipped"`
		IsReplaying       bool `json:"isReplaying"`
	} `json:"flags"`
	Metadata struct {
		Userloved      bool   `json:"userloved"`
		StartTimestamp int    `json:"startTimestamp"`
		Label          string `json:"label"`
		TrackArtURL    string `json:"trackArtUrl"`
		ArtistURL      string `json:"artistUrl"`
		TrackURL       string `json:"trackUrl"`
		UserPlayCount  int    `json:"userPlayCount"`
	} `json:"metadata"`
	ConnectorLabel  string `json:"connectorLabel"`
	ControllerTabID int    `json:"controllerTabId"`
}

type Event struct {
	EventName string
	Time      int
	Data      struct {
		Song             Song
		Songs            []Song
		IsLoved          bool
		CurrentlyPlaying bool
	}
}
