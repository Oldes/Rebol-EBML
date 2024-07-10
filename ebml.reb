REBOL [
	Title:  "Codec: EBML"
	Type:    module
	Name:    ebml
	Date:    10-Jul-2024
	Version: 0.0.1
	Author:  @Oldes
	Home:    https://github.com/Oldes/Rebol-EBML
	Rights:  MIT
	Purpose: {Decode/encode EBML (Extensible Binary Meta Language) data}
	History: [
		10-Jul-2024 @Oldes "Initial version"
	]
	Note: [
		https://www.rfc-editor.org/rfc/rfc8794.html
		https://man.archlinux.org/man/Image::ExifTool::TagNames.3pm.en
		https://www.matroska.org/technical/elements.html
		https://raw.githubusercontent.com/ietf-wg-cellar/matroska-specification/master/ebml_matroska.xml
	]
	Needs: 3.17.1 ;; Uses VINT Bincode type
]

;@@TODO: provide also a scheme!

system/options/log/ebml: 0

register-codec [
	name:  'ebml
	type:  'binary
	title: "Extensible Binary Meta Language"
	suffixes: [%.mkv %.mka %.mks %.mk3d %.webm %.weba %.ebml]

	decode: function [
		data [binary! file! url!]
	][
		unless binary? data [ data: read data ]
		decode-ebml data
	]
	encode: function[data [block!]][
		out: make binary! 1000
		foreach [id value] data [
			append out encode-ebml :id :value
		]
		out
	]
	elements: make map! [
		0#02F2         [u! EBMLMaxIDLength            ]
		0#02F3         [u! EBMLMaxSizeLength          ]
		0#0A45DFA3     [m! EBMLheader                 ]
		0#0286         [u! EBMLVersion                ]
		0#02F7         [u! EBMLReadVersion            ]
		0#0282         [s! DocType                    ]
		0#0287         [u! DocTypeVersion             ]
		0#0285         [u! DocTypeReadVersion         ]
		0#6C           [b! Void                       ]
		0#3F           [b! CRC-32                     ]
		0#08538067     [m! Segment                    ] ;; The Root Element that contains all other Top-Level Elements; see (#data-layout).
		0#014D9B74     [m! SeekHead                   ] ;; Contains seeking information of Top-Level Elements; see (#data-layout).
		0#0DBB         [m! Seek                       ] ;; Contains a single seek entry to an EBML Element.
		0#13AB         [b! SeekID                     ] ;; The binary EBML ID of a Top-Level Element.
		0#13AC         [u! SeekPosition               ] ;; The Segment Position ((#segment-position)) of a Top-Level Element.
		0#0549A966     [m! Info                       ] ;; Contains general information about the Segment.
		0#33A4         [b! SegmentUUID                ] ;; A randomly generated UID that identifies the Segment amongst many others (128 bits). It is equivalent to a Universally Unique Identifier (UUID) v4 [@!RFC4122] with all bits randomly (or pseudorandomly) chosen.  An actual UUID v4 value, where some bits are not random, **MAY** also be used.
		0#3384         [s! SegmentFilename            ] ;; A filename corresponding to this Segment.
		0#1CB923       [b! PrevUUID                   ] ;; An ID that identifies the previous Segment of a Linked Segment.
		0#1C83AB       [s! PrevFilename               ] ;; A filename corresponding to the file of the previous Linked Segment.
		0#1EB923       [b! NextUUID                   ] ;; An ID that identifies the next Segment of a Linked Segment.
		0#1E83BB       [s! NextFilename               ] ;; A filename corresponding to the file of the next Linked Segment.
		0#0444         [b! SegmentFamily              ] ;; A UID that all Segments of a Linked Segment **MUST** share (128 bits). It is equivalent to a UUID v4 [@!RFC4122] with all bits randomly (or pseudorandomly) chosen. An actual UUID v4 value, where some bits are not random, **MAY** also be used.
		0#2924         [m! ChapterTranslate           ] ;; The mapping between this `Segment` and a segment value in the given Chapter Codec.
		0#29A5         [b! ChapterTranslateID         ] ;; The binary value used to represent this Segment in the chapter codec data. The format depends on the ChapProcessCodecID used; see (#chapprocesscodecid-element).
		0#29BF         [u! ChapterTranslateCodec      ] ;; This `ChapterTranslate` applies to the chapter codec of the given chapter edition(s); see (#chapprocesscodecid-element).
		0#29FC         [u! ChapterTranslateEditionUID ] ;; Specifies a chapter edition UID to which this `ChapterTranslate` applies.
		0#0AD7B1       [u! TimestampScale             ] ;; Base unit for Segment Ticks and Track Ticks, in nanoseconds. A TimestampScale value of 1000000 means scaled timestamps in the Segment are expressed in milliseconds; see (#timestamps) on how to interpret timestamps.
		0#0489         [f! Duration                   ] ;; Duration of the Segment, expressed in Segment Ticks, which are based on TimestampScale; see (#timestamp-ticks).
		0#0461         [d! DateUTC                    ] ;; The date and time that the Segment was created by the muxing application or library.
		0#3BA9         [s! Title                      ] ;; General name of the Segment.
		0#0D80         [s! MuxingApp                  ] ;; Muxing application or library (example: "libmatroska-0.4.3").
		0#1741         [s! WritingApp                 ] ;; Writing application (example: "mkvmerge-0.3.3").
		0#0F43B675     [m! Cluster                    ] ;; The Top-Level Element containing the (monolithic) Block structure.
		0#67           [u! Timestamp                  ] ;; Absolute timestamp of the cluster, expressed in Segment Ticks, which are based on TimestampScale; see (#timestamp-ticks).
		0#1854         [m! SilentTracks               ] ;; The list of tracks that are not used in that part of the stream. It is useful when using overlay tracks for seeking or deciding what track to use.
		0#18D7         [u! SilentTrackNumber          ] ;; One of the track numbers that is not used from now on in the stream. It could change later if not specified as silent in a further Cluster.
		0#27           [u! Position                   ] ;; The Segment Position of the Cluster in the Segment (0 in live streams). It might help to resynchronize the offset on damaged streams.
		0#2B           [u! PrevSize                   ] ;; Size of the previous Cluster, in octets. Can be useful for backward playing.
		0#23           [b! SimpleBlock                ] ;; Similar to Block (see (#block-structure)) but without all the extra information. Mostly used to reduce overhead when no extra feature is needed; see (#simpleblock-structure) on SimpleBlock Structure.
		0#20           [m! BlockGroup                 ] ;; Basic container of information containing a single Block and information specific to that Block.
		0#21           [b! Block                      ] ;; Block containing the actual data to be rendered and a timestamp relative to the Cluster Timestamp; see (#block-structure) on Block Structure.
		0#22           [b! BlockVirtual               ] ;; A Block with no data. It must be stored in the stream at the place the real Block would be in display order.
		0#35A1         [m! BlockAdditions             ] ;; Contains additional binary data to complete the main one; see [@?I-D.ietf-cellar-codec, section 4.1.5] for more information. An EBML parser that has no knowledge of the Block structure could still see and use/skip these data.
		0#26           [m! BlockMore                  ] ;; Contains the BlockAdditional and some parameters.
		0#25           [b! BlockAdditional            ] ;; Interpreted by the codec as it wishes (using the BlockAddID).
		0#6E           [u! BlockAddID                 ] ;; An ID that identifies how to interpret the BlockAdditional data; see [@?I-D.ietf-cellar-codec, section 4.1.5] for more information. A value of 1 indicates that the meaning of the BlockAdditional data is defined by the codec. Any other value indicates the meaning of the BlockAdditional data is found in the BlockAddIDType found in the TrackEntry.
		0#1B           [u! BlockDuration              ] ;; The duration of the Block, expressed in Track Ticks; see (#timestamp-ticks). The BlockDuration Element can be useful at the end of a Track to define the duration of the last frame (as there is no subsequent Block available) or when there is a break in a track like for subtitle tracks.
		0#7A           [u! ReferencePriority          ] ;; This frame is referenced and has the specified cache priority. In the cache, only a frame of the same or higher priority can replace this frame. A value of 0 means the frame is not referenced.
		0#7B           [i! ReferenceBlock             ] ;; A timestamp value, relative to the timestamp of the Block in this BlockGroup, expressed in Track Ticks; see (#timestamp-ticks). This is used to reference other frames necessary to decode this frame. The relative value **SHOULD** correspond to a valid `Block` that this `Block` depends on. Historically, Matroska Writers didn't write the actual `Block(s)` that this `Block` depends on, but they did write *some* `Block(s)` in the past.  The value "0" **MAY** also be used to signify that this `Block` cannot be decoded on its own, but without knowledge of which `Block` is necessary. In this case, other `ReferenceBlock` Elements **MUST NOT** be found in the same `BlockGroup`.  If the `BlockGroup` doesn't have a `ReferenceBlock` element, then the `Block` it contains can be decoded without using any other `Block` data.
		0#7D           [i! ReferenceVirtual           ] ;; The Segment Position of the data that would otherwise be in position of the virtual block.
		0#24           [b! CodecState                 ] ;; The new codec state to use. Data interpretation is private to the codec. This information **SHOULD** always be referenced by a seek entry.
		0#35A2         [i! DiscardPadding             ] ;; Duration of the silent data added to the Block, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks) (padding at the end of the Block for positive values and at the beginning of the Block for negative values). The duration of DiscardPadding is not calculated in the duration of the TrackEntry and **SHOULD** be discarded during playback.
		0#0E           [m! Slices                     ] ;; Contains slices description.
		0#68           [m! TimeSlice                  ] ;; Contains extra time information about the data contained in the Block. Being able to interpret this Element is not required for playback.
		0#4C           [u! LaceNumber                 ] ;; The reverse number of the frame in the lace (0 is the last frame, 1 is the next to last, etc.). Being able to interpret this Element is not required for playback.
		0#4D           [u! FrameNumber                ] ;; The number of the frame to generate from this lace with this delay (allows for the generation of many frames from the same Block/Frame).
		0#4B           [u! BlockAdditionID            ] ;; The ID of the BlockAdditional Element (0 is the main Block).
		0#4E           [u! Delay                      ] ;; The delay to apply to the Element, expressed in Track Ticks; see (#timestamp-ticks).
		0#4F           [u! SliceDuration              ] ;; The duration to apply to the Element, expressed in Track Ticks; see (#timestamp-ticks).
		0#48           [m! ReferenceFrame             ] ;; Contains information about the last reference frame. See [@?DivXTrickTrack].
		0#49           [u! ReferenceOffset            ] ;; The relative offset, in bytes, from the previous BlockGroup element for this Smooth FF/RW video track to the containing BlockGroup element. See [@?DivXTrickTrack].
		0#4A           [u! ReferenceTimestamp         ] ;; The timestamp of the BlockGroup pointed to by ReferenceOffset, expressed in Track Ticks; see (#timestamp-ticks). See [@?DivXTrickTrack].
		0#2F           [b! EncryptedBlock             ] ;; Similar to SimpleBlock (see (#simpleblock-structure)), but the data inside the Block are Transformed (encrypted and/or signed).
		0#0654AE6B     [m! Tracks                     ] ;; A Top-Level Element of information with many tracks described.
		0#2E           [m! TrackEntry                 ] ;; Describes a track with all Elements.
		0#57           [u! TrackNumber                ] ;; The track number as used in the Block Header.
		0#33C5         [u! TrackUID                   ] ;; A UID that identifies the Track.
		0#03           [u! TrackType                  ] ;; The `TrackType` defines the type of each frame found in the Track. The value **SHOULD** be stored on 1 octet.
		0#39           [u! FlagEnabled                ] ;; Set to 1 if the track is usable. It is possible to turn a track that is not usable into a usable track using chapter codecs or control tracks.
		0#08           [u! FlagDefault                ] ;; Set if the track (audio, video, or subs) is eligible for automatic selection by the player; see (#default-track-selection) for more details.
		0#15AA         [u! FlagForced                 ] ;; Applies only to subtitles. Set if the track is eligible for automatic selection by the player if it matches the user's language preference, even if the user's preferences would not normally enable subtitles with the selected audio track; this can be used for tracks containing only translations of audio in foreign languages or on-screen text. See (#default-track-selection) for more details.
		0#15AB         [u! FlagHearingImpaired        ] ;; Set to 1 if and only if the track is suitable for users with hearing impairments.
		0#15AC         [u! FlagVisualImpaired         ] ;; Set to 1 if and only if the track is suitable for users with visual impairments.
		0#15AD         [u! FlagTextDescriptions       ] ;; Set to 1 if and only if the track contains textual descriptions of video content.
		0#15AE         [u! FlagOriginal               ] ;; Set to 1 if and only if the track is in the content's original language.
		0#15AF         [u! FlagCommentary             ] ;; Set to 1 if and only if the track contains commentary.
		0#1C           [u! FlagLacing                 ] ;; Set to 1 if the track **MAY** contain blocks that use lacing. When set to 0, all blocks **MUST** have their lacing flags set to "no lacing"; see (#block-lacing) on Block Lacing.
		0#2DE7         [u! MinCache                   ] ;; The minimum number of frames a player should be able to cache during playback. If set to 0, the reference pseudo-cache system is not used.
		0#2DF8         [u! MaxCache                   ] ;; The maximum cache size necessary to store referenced frames in and the current frame. 0 means no cache is needed.
		0#03E383       [u! DefaultDuration            ] ;; Number of nanoseconds per frame, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks) ("frame" in the Matroska sense -- one Element put into a (Simple)Block).
		0#034E7A       [u! DefaultDecodedFieldDuration] ;; The period between two successive fields at the output of the decoding process, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks). See (#defaultdecodedfieldduration) for more information.
		0#03314F       [b! TrackTimestampScale        ] ;; The scale to apply on this track to work at normal speed in relation with other tracks (mostly used to adjust video speed when the audio length differs).
		0#137F         [i! TrackOffset                ] ;; A value to add to the Block's Timestamp, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks). This can be used to adjust the playback offset of a track.
		0#15EE         [u! MaxBlockAdditionID         ] ;; The maximum value of BlockAddID ((#blockaddid-element)). A value of 0 means there is no BlockAdditions ((#blockadditions-element)) for this track.
		0#01E4         [m! BlockAdditionMapping       ] ;; Contains elements that extend the track format by adding content either to each frame, with BlockAddID ((#blockaddid-element)), or to the track as a whole with BlockAddIDExtraData.
		0#01F0         [u! BlockAddIDValue            ] ;; If the track format extension needs content beside frames, the value refers to the BlockAddID ((#blockaddid-element)) value being described.
		0#01A4         [s! BlockAddIDName             ] ;; A human-friendly name describing the type of BlockAdditional data, as defined by the associated Block Additional Mapping.
		0#01E7         [u! BlockAddIDType             ] ;; Stores the registered identifier of the Block Additional Mapping to define how the BlockAdditional data should be handled.
		0#01ED         [b! BlockAddIDExtraData        ] ;; Extra binary data that the BlockAddIDType can use to interpret the BlockAdditional data. The interpretation of the binary data depends on the BlockAddIDType value and the corresponding Block Additional Mapping.
		0#136E         [s! Name                       ] ;; A human-readable track name.
		0#02B59C       [s! Language                   ] ;; The language of the track, in the Matroska languages form; see (#language-codes) on language codes. This Element **MUST** be ignored if the LanguageBCP47 Element is used in the same TrackEntry.
		0#02B59D       [s! LanguageBCP47              ] ;; The language of the track, in the form defined in [@!RFC5646]; see (#language-codes) on language codes. If this Element is used, then any Language Elements used in the same TrackEntry **MUST** be ignored.
		0#06           [s! CodecID                    ] ;; An ID corresponding to the codec; see [@?I-D.ietf-cellar-codec] for more info.
		0#23A2         [b! CodecPrivate               ] ;; Private data only known to the codec.
		0#058688       [s! CodecName                  ] ;; A human-readable string specifying the codec.
		0#3446         [u! AttachmentLink             ] ;; The UID of an attachment that is used by this codec.
		0#1A9697       [s! CodecSettings              ] ;; A string describing the encoding setting used.
		0#1B4040       [s! CodecInfoURL               ] ;; A URL to find information about the codec used.
		0#06B240       [s! CodecDownloadURL           ] ;; A URL to download about the codec used.
		0#2A           [u! CodecDecodeAll             ] ;; Set to 1 if the codec can decode potentially damaged data.
		0#2FAB         [u! TrackOverlay               ] ;; Specify that this track is an overlay track for the Track specified (in the u-integer). This means that when this track has a gap on SilentTracks, the overlay track should be used instead. The order of multiple TrackOverlay matters; the first one is the one that should be used. If the first one is not found, it should be the second, etc.
		0#16AA         [u! CodecDelay                 ] ;; The built-in delay for the codec, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks). It represents the number of codec samples that will be discarded by the decoder during playback. This timestamp value **MUST** be subtracted from each frame timestamp in order to get the timestamp that will be actually played. The value **SHOULD** be small so the muxing of tracks with the same actual timestamp are in the same Cluster.
		0#16BB         [u! SeekPreRoll                ] ;; After a discontinuity, the duration of the data that the decoder **MUST** decode before the decoded data is valid, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks).
		0#2624         [m! TrackTranslate             ] ;; The mapping between this `TrackEntry` and a track value in the given Chapter Codec.
		0#26A5         [b! TrackTranslateTrackID      ] ;; The binary value used to represent this `TrackEntry` in the chapter codec data. The format depends on the `ChapProcessCodecID` used; see (#chapprocesscodecid-element).
		0#26BF         [u! TrackTranslateCodec        ] ;; This `TrackTranslate` applies to the chapter codec of the given chapter edition(s); see (#chapprocesscodecid-element).
		0#26FC         [u! TrackTranslateEditionUID   ] ;; Specifies a chapter edition UID to which this `TrackTranslate` applies.
		0#60           [m! Video                      ] ;; Video settings.
		0#1A           [u! FlagInterlaced             ] ;; Specifies whether the video frames in this track are interlaced.
		0#1D           [u! FieldOrder                 ] ;; Specifies the field ordering of video frames in this track.
		0#13B8         [u! StereoMode                 ] ;; Stereo-3D video mode. See (#multi-planar-and-3d-videos) for more details.
		0#13C0         [u! AlphaMode                  ] ;; Indicates whether the BlockAdditional Element with BlockAddID of "1" contains Alpha data, as defined by the Codec Mapping for the `CodecID`. Undefined values **SHOULD NOT** be used, as the behavior of known implementations is different (considered either as 0 or 1).
		0#13B9         [u! OldStereoMode              ] ;; Bogus StereoMode value used in old versions of [@?libmatroska].
		0#30           [u! PixelWidth                 ] ;; Width of the encoded video frames in pixels.
		0#3A           [u! PixelHeight                ] ;; Height of the encoded video frames in pixels.
		0#14AA         [u! PixelCropBottom            ] ;; The number of video pixels to remove at the bottom of the image.
		0#14BB         [u! PixelCropTop               ] ;; The number of video pixels to remove at the top of the image.
		0#14CC         [u! PixelCropLeft              ] ;; The number of video pixels to remove on the left of the image.
		0#14DD         [u! PixelCropRight             ] ;; The number of video pixels to remove on the right of the image.
		0#14B0         [u! DisplayWidth               ] ;; Width of the video frames to display. Applies to the video frame after cropping (PixelCrop* Elements).
		0#14BA         [u! DisplayHeight              ] ;; Height of the video frames to display. Applies to the video frame after cropping (PixelCrop* Elements).
		0#14B2         [u! DisplayUnit                ] ;; How DisplayWidth and DisplayHeight are interpreted.
		0#14B3         [u! AspectRatioType            ] ;; Specifies the possible modifications to the aspect ratio.
		0#0EB524       [b! UncompressedFourCC         ] ;; Specifies the uncompressed pixel format used for the Track's data as a FourCC. This value is similar in scope to the biCompression value of AVI's `BITMAPINFO` [@?AVIFormat]. There is neither a definitive list of FourCC values nor an official registry. Some common values for YUV pixel formats can be found at [@?MSYUV8], [@?MSYUV16], and [@?FourCC-YUV]. Some common values for uncompressed RGB pixel formats can be found at [@?MSRGB] and [@?FourCC-RGB].
		0#0FB523       [b! GammaValue                 ] ;; Gamma value.
		0#0383E3       [b! FrameRate                  ] ;; Number of frames per second. This value is informational only. It is intended for constant frame rate streams and should not be used for a variable frame rate TrackEntry.
		0#15B0         [m! Colour                     ] ;; Settings describing the color format.
		0#15B1         [u! MatrixCoefficients         ] ;; The Matrix Coefficients of the video used to derive luma and chroma values from red, green, and blue color primaries. For clarity, the value and meanings for MatrixCoefficients are adopted from Table 4 of [@!ITU-H.273].
		0#15B2         [u! BitsPerChannel             ] ;; Number of decoded bits per channel. A value of 0 indicates that the BitsPerChannel is unspecified.
		0#15B3         [u! ChromaSubsamplingHorz      ] ;; The number of pixels to remove in the Cr and Cb channels for every pixel not removed horizontally. Example: For video with 4:2:0 chroma subsampling, the ChromaSubsamplingHorz **SHOULD** be set to 1.
		0#15B4         [u! ChromaSubsamplingVert      ] ;; The number of pixels to remove in the Cr and Cb channels for every pixel not removed vertically. Example: For video with 4:2:0 chroma subsampling, the ChromaSubsamplingVert **SHOULD** be set to 1.
		0#15B5         [u! CbSubsamplingHorz          ] ;; The number of pixels to remove in the Cb channel for every pixel not removed horizontally. This is additive with ChromaSubsamplingHorz. Example: For video with 4:2:1 chroma subsampling, the ChromaSubsamplingHorz **SHOULD** be set to 1, and CbSubsamplingHorz **SHOULD** be set to 1.
		0#15B6         [u! CbSubsamplingVert          ] ;; The number of pixels to remove in the Cb channel for every pixel not removed vertically. This is additive with ChromaSubsamplingVert.
		0#15B7         [u! ChromaSitingHorz           ] ;; How chroma is subsampled horizontally.
		0#15B8         [u! ChromaSitingVert           ] ;; How chroma is subsampled vertically.
		0#15B9         [u! Range                      ] ;; Clipping of the color ranges.
		0#15BA         [u! TransferCharacteristics    ] ;; The transfer characteristics of the video. For clarity, the value and meanings for TransferCharacteristics are adopted from Table 3 of [@!ITU-H.273].
		0#15BB         [u! Primaries                  ] ;; The color primaries of the video. For clarity, the value and meanings for Primaries are adopted from Table 2 of [@!ITU-H.273].
		0#15BC         [u! MaxCLL                     ] ;; Maximum brightness of a single pixel (Maximum Content Light Level) in candelas per square meter (cd/m^2^).
		0#15BD         [u! MaxFALL                    ] ;; Maximum brightness of a single full frame (Maximum Frame-Average Light Level) in candelas per square meter (cd/m^2^).
		0#15D0         [m! MasteringMetadata          ] ;; SMPTE 2086 mastering data.
		0#15D1         [b! PrimaryRChromaticityX      ] ;; Red X chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D2         [b! PrimaryRChromaticityY      ] ;; Red Y chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D3         [b! PrimaryGChromaticityX      ] ;; Green X chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D4         [b! PrimaryGChromaticityY      ] ;; Green Y chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D5         [b! PrimaryBChromaticityX      ] ;; Blue X chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D6         [b! PrimaryBChromaticityY      ] ;; Blue Y chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D7         [b! WhitePointChromaticityX    ] ;; White X chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D8         [b! WhitePointChromaticityY    ] ;; White Y chromaticity coordinate, as defined by [@!CIE-1931].
		0#15D9         [b! LuminanceMax               ] ;; Maximum luminance. Represented in candelas per square meter (cd/m^2^).
		0#15DA         [b! LuminanceMin               ] ;; Minimum luminance. Represented in candelas per square meter (cd/m^2^).
		0#3670         [m! Projection                 ] ;; Describes the video projection details. Used to render spherical or VR videos or to flip videos horizontally or vertically.
		0#3671         [u! ProjectionType             ] ;; Describes the projection used for this video track.
		0#3672         [b! ProjectionPrivate          ] ;; Private data that only applies to a specific projection. *  If `ProjectionType` equals 0 (rectangular),      then this element **MUST NOT** be present. *  If `ProjectionType` equals 1 (equirectangular), then this element **MUST** be present and contain the same binary data that would be stored inside       an ISOBMFF Equirectangular Projection Box ("equi"). *  If `ProjectionType` equals 2 (cubemap), then this element **MUST** be present and contain the same binary data that would be stored       inside an ISOBMFF Cubemap Projection Box ("cbmp"). *  If `ProjectionType` equals 3 (mesh), then this element **MUST** be present and contain the same binary data that would be stored inside        an ISOBMFF Mesh Projection Box ("mshp").
		0#3673         [b! ProjectionPoseYaw          ] ;; Specifies a yaw rotation to the projection.  Value represents a clockwise rotation, in degrees, around the up vector. This rotation must be applied before any `ProjectionPosePitch` or `ProjectionPoseRoll` rotations. The value of this element **MUST** be in the -180 to 180 degree range, both included.  Setting `ProjectionPoseYaw` to 180 or -180 degrees with `ProjectionPoseRoll` and `ProjectionPosePitch` set to 0 degrees flips the image horizontally.
		0#3674         [b! ProjectionPosePitch        ] ;; Specifies a pitch rotation to the projection.  Value represents a counter-clockwise rotation, in degrees, around the right vector. This rotation must be applied after the `ProjectionPoseYaw` rotation and before the `ProjectionPoseRoll` rotation. The value of this element **MUST** be in the -90 to 90 degree range, both included.
		0#3675         [b! ProjectionPoseRoll         ] ;; Specifies a roll rotation to the projection.  Value represents a counter-clockwise rotation, in degrees, around the forward vector. This rotation must be applied after the `ProjectionPoseYaw` and `ProjectionPosePitch` rotations. The value of this element **MUST** be in the -180 to 180 degree range, both included.  Setting `ProjectionPoseRoll` to 180 or -180 degrees and `ProjectionPoseYaw` to 180 or -180 degrees with `ProjectionPosePitch` set to 0 degrees flips the image vertically.  Setting `ProjectionPoseRoll` to 180 or -180 degrees with `ProjectionPoseYaw` and `ProjectionPosePitch` set to 0 degrees flips the image horizontally and vertically.
		0#61           [m! Audio                      ] ;; Audio settings.
		0#35           [b! SamplingFrequency          ] ;; Sampling frequency in Hz.
		0#38B5         [b! OutputSamplingFrequency    ] ;; Real output sampling frequency in Hz (used for SBR techniques).
		0#1F           [u! Channels                   ] ;; Numbers of channels in the track.
		0#3D7B         [b! ChannelPositions           ] ;; Table of horizontal angles for each successive channel.
		0#2264         [u! BitDepth                   ] ;; Bits per sample, mostly used for PCM.
		0#12F1         [u! Emphasis                   ] ;; Audio emphasis applied on audio samples. The player **MUST** apply the inverse emphasis to get the proper audio samples.
		0#62           [m! TrackOperation             ] ;; Operation that needs to be applied on tracks to create this virtual track. For more details, see (#track-operation).
		0#63           [m! TrackCombinePlanes         ] ;; Contains the list of all video plane tracks that need to be combined to create this 3D track.
		0#64           [m! TrackPlane                 ] ;; Contains a video plane track that needs to be combined to create this 3D track.
		0#65           [u! TrackPlaneUID              ] ;; The trackUID number of the track representing the plane.
		0#66           [u! TrackPlaneType             ] ;; The kind of plane this track corresponds to.
		0#69           [m! TrackJoinBlocks            ] ;; Contains the list of all tracks whose Blocks need to be combined to create this virtual track.
		0#6D           [u! TrackJoinUID               ] ;; The trackUID number of a track whose blocks are used to create this virtual track.
		0#40           [u! TrickTrackUID              ] ;; The TrackUID of the Smooth FF/RW video in the paired EBML structure corresponding to this video track. See [@?DivXTrickTrack].
		0#41           [b! TrickTrackSegmentUID       ] ;; The SegmentUID of the Segment containing the track identified by TrickTrackUID. See [@?DivXTrickTrack].
		0#46           [u! TrickTrackFlag             ] ;; Set to 1 if this video track is a Smooth FF/RW track. If set to 1, MasterTrackUID and MasterTrackSegUID should be present, and BlockGroups for this track must contain ReferenceFrame structures. Otherwise, TrickTrackUID and TrickTrackSegUID must be present if this track has a corresponding Smooth FF/RW track. See [@?DivXTrickTrack].
		0#47           [u! TrickMasterTrackUID        ] ;; The TrackUID of the video track in the paired EBML structure that corresponds to this Smooth FF/RW track. See [@?DivXTrickTrack].
		0#44           [b! TrickMasterTrackSegmentUID ] ;; The SegmentUID of the Segment containing the track identified by MasterTrackUID. See [@?DivXTrickTrack].
		0#2D80         [m! ContentEncodings           ] ;; Settings for several content encoding mechanisms like compression or encryption.
		0#2240         [m! ContentEncoding            ] ;; Settings for one content encoding like compression or encryption.
		0#1031         [u! ContentEncodingOrder       ] ;; Tell in which order to apply each `ContentEncoding` of the `ContentEncodings`. The decoder/demuxer **MUST** start with the `ContentEncoding` with the highest `ContentEncodingOrder` and work its way down to the `ContentEncoding` with the lowest `ContentEncodingOrder`. This value **MUST** be unique for each `ContentEncoding` found in the `ContentEncodings` of this `TrackEntry`.
		0#1032         [u! ContentEncodingScope       ] ;; A bit field that describes which Elements have been modified in this way. Values (big-endian) can be OR'ed.
		0#1033         [u! ContentEncodingType        ] ;; A value describing the kind of transformation that is applied.
		0#1034         [m! ContentCompression         ] ;; Settings describing the compression used. This Element **MUST** be present if the value of ContentEncodingType is 0 and absent otherwise. Each block **MUST** be decompressable, even if no previous block is available in order to not prevent seeking.
		0#0254         [u! ContentCompAlgo            ] ;; The compression algorithm used.
		0#0255         [b! ContentCompSettings        ] ;; Settings that might be needed by the decompressor. For Header Stripping (`ContentCompAlgo`=3), the bytes that were removed from the beginning of each frame of the track.
		0#1035         [m! ContentEncryption          ] ;; Settings describing the encryption used. This Element **MUST** be present if the value of `ContentEncodingType` is 1 (encryption) and **MUST** be ignored otherwise. A Matroska Player **MAY** support encryption.
		0#07E1         [u! ContentEncAlgo             ] ;; The encryption algorithm used.
		0#07E2         [b! ContentEncKeyID            ] ;; For public key algorithms, the ID of the public key that the data was encrypted with.
		0#07E7         [m! ContentEncAESSettings      ] ;; Settings describing the encryption algorithm used.
		0#07E8         [u! AESSettingsCipherMode      ] ;; The AES cipher mode used in the encryption.
		0#07E3         [b! ContentSignature           ] ;; A cryptographic signature of the contents.
		0#07E4         [b! ContentSigKeyID            ] ;; This is the ID of the private key that the data was signed with.
		0#07E5         [u! ContentSigAlgo             ] ;; The algorithm used for the signature.
		0#07E6         [u! ContentSigHashAlgo         ] ;; The hash algorithm used for the signature.
		0#0C53BB6B     [m! Cues                       ] ;; A Top-Level Element to speed seeking access. All entries are local to the Segment.
		0#3B           [m! CuePoint                   ] ;; Contains all information relative to a seek point in the Segment.
		0#33           [u! CueTime                    ] ;; Absolute timestamp of the seek point, expressed in Segment Ticks, which are based on TimestampScale; see (#timestamp-ticks).
		0#37           [m! CueTrackPositions          ] ;; Contains positions for different tracks corresponding to the timestamp.
		0#77           [u! CueTrack                   ] ;; The track for which a position is given.
		0#71           [u! CueClusterPosition         ] ;; The Segment Position ((#segment-position)) of the Cluster containing the associated Block.
		0#70           [u! CueRelativePosition        ] ;; The relative position inside the Cluster of the referenced SimpleBlock or BlockGroup with 0 being the first possible position for an Element inside that Cluster.
		0#32           [u! CueDuration                ] ;; The duration of the block, expressed in Segment Ticks, which are based on TimestampScale; see (#timestamp-ticks). If missing, the track's DefaultDuration does not apply and no duration information is available in terms of the cues.
		0#1378         [u! CueBlockNumber             ] ;; Number of the Block in the specified Cluster.
		0#6A           [u! CueCodecState              ] ;; The Segment Position ((#segment-position)) of the Codec State corresponding to this Cue Element. 0 means that the data is taken from the initial Track Entry.
		0#5B           [m! CueReference               ] ;; The Clusters containing the referenced Blocks.
		0#16           [u! CueRefTime                 ] ;; Timestamp of the referenced Block, expressed in Segment Ticks which is based on TimestampScale; see (#timestamp-ticks).
		0#17           [u! CueRefCluster              ] ;; The Segment Position of the Cluster containing the referenced Block.
		0#135F         [u! CueRefNumber               ] ;; Number of the referenced Block of Track X in the specified Cluster.
		0#6B           [u! CueRefCodecState           ] ;; The Segment Position of the Codec State corresponding to this referenced Element. 0 means that the data is taken from the initial Track Entry.
		0#0941A469     [m! Attachments                ] ;; Contains attached files.
		0#21A7         [m! AttachedFile               ] ;; An attached file.
		0#067E         [s! FileDescription            ] ;; A human-friendly name for the attached file.
		0#066E         [s! FileName                   ] ;; Filename of the attached file.
		0#0660         [s! FileMediaType              ] ;; Media type of the file following the format described in [@!RFC6838].
		0#065C         [b! FileData                   ] ;; The data of the file.
		0#06AE         [u! FileUID                    ] ;; UID representing the file, as random as possible.
		0#0675         [b! FileReferral               ] ;; A binary value that a track/codec can refer to when the attachment is needed.
		0#0661         [u! FileUsedStartTime          ] ;; The timestamp at which this optimized font attachment comes into context, expressed in Segment Ticks, which are based on TimestampScale. See [@?DivXWorldFonts].
		0#0662         [u! FileUsedEndTime            ] ;; The timestamp at which this optimized font attachment goes out of context, expressed in Segment Ticks, which are based on TimestampScale. See [@?DivXWorldFonts].
		0#43A770       [m! Chapters                   ] ;; A system to define basic menus and partition data. For more detailed information, see (#chapters).
		0#05B9         [m! EditionEntry               ] ;; Contains all information about a Segment edition.
		0#05BC         [u! EditionUID                 ] ;; A UID that identifies the edition. It's useful for tagging an edition.
		0#05BD         [u! EditionFlagHidden          ] ;; Set to 1 if an edition is hidden. Hidden editions **SHOULD NOT** be available to the user interface (but still to Control Tracks; see (#chapter-flags) on Chapter flags).
		0#05DB         [u! EditionFlagDefault         ] ;; Set to 1 if the edition **SHOULD** be used as the default one.
		0#05DD         [u! EditionFlagOrdered         ] ;; Set to 1 if the chapters can be defined multiple times and the order to play them is enforced; see (#editionflagordered).
		0#0520         [m! EditionDisplay             ] ;; Contains a possible string to use for the edition display for the given languages.
		0#0521         [s! EditionString              ] ;; Contains the string to use as the edition name.
		0#05E4         [s! EditionLanguageIETF        ] ;; One language corresponding to the EditionString, in the form defined in [@!RFC5646]; see (#language-codes) on language codes.
		0#36           [m! ChapterAtom                ] ;; Contains the atom information to use as the chapter atom (applies to all tracks).
		0#33C4         [u! ChapterUID                 ] ;; A UID that identifies the Chapter.
		0#1654         [s! ChapterStringUID           ] ;; A unique string ID that identifies the Chapter. For example, it is used as the storage for cue identifier values [@?WebVTT].
		0#11           [u! ChapterTimeStart           ] ;; Timestamp of the start of Chapter, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks).
		0#12           [u! ChapterTimeEnd             ] ;; Timestamp of the end of Chapter timestamp excluded, expressed in Matroska Ticks -- i.e., in nanoseconds; see (#timestamp-ticks). The value **MUST** be greater than or equal to the `ChapterTimeStart` of the same `ChapterAtom`.
		0#18           [u! ChapterFlagHidden          ] ;; Set to 1 if a chapter is hidden. Hidden chapters **SHOULD NOT** be available to the user interface (but still to Control Tracks; see (#chapterflaghidden) on Chapter flags).
		0#0598         [u! ChapterFlagEnabled         ] ;; Set to 1 if the chapter is enabled. It can be enabled/disabled by a Control Track. When disabled, the movie **SHOULD** skip all the content between the TimeStart and TimeEnd of this chapter; see (#chapter-flags) on Chapter flags.
		0#2E67         [b! ChapterSegmentUUID         ] ;; The SegmentUUID of another Segment to play during this chapter.
		0#0588         [u! ChapterSkipType            ] ;; Indicates what type of content the ChapterAtom contains and might be skipped. It can be used to automatically skip content based on the type. If a `ChapterAtom` is inside a `ChapterAtom` that has a `ChapterSkipType` set, it **MUST NOT** have a `ChapterSkipType` or have a `ChapterSkipType` with the same value as it's parent `ChapterAtom`. If the `ChapterAtom` doesn't contain a `ChapterTimeEnd`, the value of the `ChapterSkipType` is only valid until the next `ChapterAtom` with a `ChapterSkipType` value or the end of the file.
		0#2EBC         [u! ChapterSegmentEditionUID   ] ;; The EditionUID to play from the Segment linked in ChapterSegmentUUID. If ChapterSegmentEditionUID is undeclared, then no Edition of the linked Segment is used; see (#medium-linking) on Medium-Linking Segments.
		0#23C3         [u! ChapterPhysicalEquiv       ] ;; Specifies the physical equivalent of this ChapterAtom, e.g., "DVD" (60) or "SIDE" (50); see (#physical-types) for a complete list of values.
		0#0F           [m! ChapterTrack               ] ;; List of tracks on which the chapter applies. If this Element is not present, all tracks apply.
		0#09           [u! ChapterTrackUID            ] ;; UID of the Track to apply this chapter to. In the absence of a control track, choosing this chapter will select the listed Tracks and deselect unlisted tracks. Absence of this Element indicates that the Chapter **SHOULD** be applied to any currently used Tracks.
		0#00           [m! ChapterDisplay             ] ;; Contains all possible strings to use for the chapter display.
		0#05           [s! ChapString                 ] ;; Contains the string to use as the chapter atom.
		0#037C         [s! ChapLanguage               ] ;; A language corresponding to the string, in the Matroska languages form; see (#language-codes) on language codes. This Element **MUST** be ignored if a ChapLanguageBCP47 Element is used within the same ChapterDisplay Element.
		0#037D         [s! ChapLanguageBCP47          ] ;; A language corresponding to the ChapString, in the form defined in [@!RFC5646]; see (#language-codes) on language codes. If a ChapLanguageBCP47 Element is used, then any ChapLanguage and ChapCountry Elements used in the same ChapterDisplay **MUST** be ignored.
		0#037E         [s! ChapCountry                ] ;; A country corresponding to the string, in the Matroska countries form; see (#country-codes) on country codes. This Element **MUST** be ignored if a ChapLanguageBCP47 Element is used within the same ChapterDisplay Element.
		0#2944         [m! ChapProcess                ] ;; Contains all the commands associated with the Atom.
		0#2955         [u! ChapProcessCodecID         ] ;; Contains the type of the codec used for processing. A value of 0 means built-in Matroska processing (to be defined), and a value of 1 means the DVD command set is used; see (#menu-features) on DVD menus. More codec IDs can be added later.
		0#050D         [b! ChapProcessPrivate         ] ;; Optional data attached to the ChapProcessCodecID information.     For ChapProcessCodecID = 1, it is the "DVD level" equivalent; see (#menu-features) on DVD menus.
		0#2911         [m! ChapProcessCommand         ] ;; Contains all the commands associated with the Atom.
		0#2922         [u! ChapProcessTime            ] ;; Defines when the process command **SHOULD** be handled.
		0#2933         [b! ChapProcessData            ] ;; Contains the command information. The data **SHOULD** be interpreted depending on the ChapProcessCodecID value. For ChapProcessCodecID = 1, the data correspond to the binary DVD cell pre/post commands; see (#menu-features) on DVD menus.
		0#0254C367     [m! Tags                       ] ;; Element containing metadata describing Tracks, Editions, Chapters, Attachments, or the Segment as a whole. A list of valid tags can be found in [@?I-D.ietf-cellar-tags].
		0#3373         [m! Tag                        ] ;; A single metadata descriptor.
		0#23C0         [m! Targets                    ] ;; Specifies which other elements the metadata represented by the Tag applies to. If empty or omitted, then the Tag describes everything in the Segment.
		0#28CA         [u! TargetTypeValue            ] ;; A number to indicate the logical level of the target.
		0#23CA         [s! TargetType                 ] ;; An informational string that can be used to display the logical level of the target, such as "ALBUM", "TRACK", "MOVIE", "CHAPTER", etc.
		0#23C5         [u! TagTrackUID                ] ;; A UID that identifies the Track(s) that the tags belong to.
		0#23C9         [u! TagEditionUID              ] ;; A UID that identifies the EditionEntry(s) that the tags belong to.
		0#23C4         [u! TagChapterUID              ] ;; A UID that identifies the Chapter(s) that the tags belong to.
		0#23C6         [u! TagAttachmentUID           ] ;; A UID that identifies the Attachment(s) that the tags belong to.
		0#27C8         [m! SimpleTag                  ] ;; Contains general information about the target.
		0#05A3         [s! TagName                    ] ;; The name of the Tag that is going to be stored.
		0#047A         [s! TagLanguage                ] ;; Specifies the language of the specified tag in the Matroska languages form; see (#language-codes) on language codes. This Element **MUST** be ignored if the TagLanguageBCP47 Element is used within the same SimpleTag Element.
		0#047B         [s! TagLanguageBCP47           ] ;; The language used in the TagString, in the form defined in [@!RFC5646]; see (#language-codes) on language codes. If this Element is used, then any TagLanguage Elements used in the same SimpleTag **MUST** be ignored.
		0#0484         [u! TagDefault                 ] ;; A boolean value to indicate if this is the default/original language to use for the given tag.
		0#04B4         [u! TagDefaultBogus            ] ;; A variant of the TagDefault element with a bogus Element ID; see (#tagdefault-element).
		0#0487         [s! TagString                  ] ;; The value of the Tag.
		0#0485         [b! TagBinary                  ] ;; The values of the Tag if it is binary. Note that this cannot be used in the same SimpleTag as TagString.
		;; unknown types...	
		0#2532         [b! SignedElement              ] ;; An element ID whose data will be used to compute the signature.
		0#3E5B         [m! SignatureElements          ] ;; Contains elements that will be used to compute the signature.
		0#3E7B         [m! SignatureElementList       ] ;; A list consists of a number of consecutive elements that represent one case where data is used in signature. Ex: Cluster|Block|BlockAdditional means that the BlockAdditional of all Blocks in all Clusters is used for encryption.
		0#3E8A         [u! SignatureAlgo              ] ;; Signature algorithm used (1=RSA, 2=elliptic).
		0#3E9A         [u! SignatureHash              ] ;; Hash algorithm used (1=SHA1-160, 2=MD5).
		0#3EA5         [b! SignaturePublicKey         ] ;; The public key to use with the algorithm (in the case of a PKI-based signature).
		0#3EB5         [n! Signature                  ] ;; The signature of the data.
		0#7670         [n! Projection                 ]
		0#0B538667     [m! SignatureSlot              ] ;; Contain signature of some (coming) elements in the stream.
	]

	element-ids: make map! length? elements
	foreach [id spec] elements [put element-ids spec/2 id]

	decode-ebml: function/with [data [binary!] /part limit][
		if part [limit: limit + index? data]
		;? limit
		out: make block! 8
		append/dup indentation SP 2
		verbose?: system/options/log/ebml > 0
		debug?:   system/options/log/ebml > 1
		while [not tail? data][
			;? data
			binary/read data [
				idx: INDEXZ
				id:  VINT
				len: VINT
				pos: INDEX
			]
			data: at head data pos
			either spec: elements/:id [
				;? spec ? len
				if verbose? [prin ajoin [indentation spec/2 ": "]]
				switch/default spec/1 [
					m! [
						if verbose? [print either debug? [as-blue ajoin [#";" idx]][""]]
						either len > 0 [
							value: decode-ebml/part data len
						][
							value: copy []
						]
					]
					b! [
						value: copy/part data len
					]
					i! u! [
						value: 0
						loop len [
							value: value << 8 + data/1
							data: next data
						]
					]
					s! [
						value: to string! copy/part data len
					]
					n! [
						value: copy/part data len
					]
					d! [
						value: 2001-01-01/0:0 + to time! ((to integer! copy/part data len) / 1000000000)
					]
					f! [
						value: to decimal! copy/part data len
					]
				][ do make error! ajoin ["Invalid EBML value type: " mold/flat spec/1] ]
				id: to set-word! spec/2
			][
				value: copy/part data len
				if verbose? [
					prin ajoin [indentation as-red 'UnknownTag ": " as-yellow trim to binary! id " len: " len " data: "]
				]
			]
			data: at head data (pos + len)
			append/only append out id value 
			if all [verbose? value not block? value] [print mold/flat/part value 60]
			pos: index? data
			if limit [
				if pos == limit [ break ]
				if pos > limit [
					sys/log/error 'EBML [as-red "[EBML] Read over limit! " pos #">" limit]
					break
				]
			]
		]
		take/last/part indentation 2
		new-line/skip out true 2
		out
	][
		indentation: ""
	]

	encode-ebml: function[id [integer! any-word!] value][
		unless integer? id [id: element-ids/:id]
		bin: switch type?/word value [
			integer! [ either zero? value [#{00}][trim/head to binary! value] ]
			binary!  [ value ]
			string!  [ to binary! value ]
			block!   [ encode value ]
			date!    [ to binary! (((to integer! value) - 978307200) * 1000000000)]
			decimal! [ to binary! value ]
		]
		either bin [
			len: length? bin
			out: binary len + 20
			binary/write out [VINT :id VINT :len BYTES :bin]
		][	? value do make error! "Unsupported EBML value!" ]
		out/buffer
	]
]

