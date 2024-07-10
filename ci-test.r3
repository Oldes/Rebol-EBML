Rebol [
	title: "Rebol/EBML extension CI test"
]

print ["Running test on Rebol build:" mold to-block system/build]
system/options/quiet: false
system/options/log/rebol: 4

;; make sure that we load a fresh extension
try [system/modules/ebml: none]
try [system/codecs/ebml:  none]
;; use current directory as a modules location
system/options/modules: what-dir

;; import the extension
import 'ebml

system/options/log/ebml: 4

;- Decode test file                                
data: load %assets/sample_640x360.webm
print-horizontal-line
;; Print some decoded content
?? data/Segment/Info

print-horizontal-line
;- Encode data back to binary                      
save %assets/test.webm data

;; Compare the encoded file with the original      
check1: checksum %assets/sample_640x360.webm 'sha1
check2: checksum %assets/test.webm 'sha1

delete %assets/test.webm

either check1 == check2 [
    print as-green "Encoded file is identical!"
][  print as-red "Test output is not same!" quit/return -1]