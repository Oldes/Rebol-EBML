[![Gitter](https://badges.gitter.im/rebol3/community.svg)](https://app.gitter.im/#/room/#Rebol3:gitter.im)

# Rebol/EBML

EBML (Extensible Binary Meta Language) codec for [Rebol3](https://github.com/Oldes/Rebol3) (version 3.17.1 and higher)

## Usage
```rebol
import ebml               ;; import the module
data: load %source.mkv    ;; decode some data
save %temp.mkv data       ;; encode data back to file
```
It is possible to use `encode`/`decode` functions like:
```rebol
data: encode 'ebml [
    Info: [
        MuxingApp: "libebml2 v0.21.3 + libmatroska2 v0.22.3"
        WritingApp: "mkclean 0.9.0 u from Lavf57.83.100"
        DateUTC: 2024-07-10T11:29:13
    ]
]
probe data
;== #{
;1549A966DA4D80A76C696265626D6C322076302E32312E33202B206C69626D61
;74726F736B61322076302E32322E335741A26D6B636C65616E20302E392E3020
;752066726F6D204C61766635372E38332E3130304461880A4D315499011A00}

probe decode 'ebml data
;== [
;    Info: [
;        MuxingApp: "libebml2 v0.21.3 + libmatroska2 v0.22.3"
;        WritingApp: "mkclean 0.9.0 u from Lavf57.83.100"
;        DateUTC: 10-Jul-2024/11:29:13
;    ]
;]
```
