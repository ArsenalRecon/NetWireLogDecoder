## Intro ##

Arsenal's NetWire Log Decoder carves and parses (a/k/a scans, filters, and decodes) NetWire log data from files or devices. NetWire is a popular multi-platform remote access trojan (RAT) system. NetWire has surveillance functionality which stores keystrokes and other information from victims in log files known as "NetWire logs." Arsenal has found valuable NetWire log data in many places within disk images other than intact NetWire logs - for example, in properly processed Windows hibernation data, crash dumps, swap files, file slack, and unallocated space. Since NetWire log data has no file format or defined data structure to parse, NetWire Log Decoder searches for typical byte sequences (signatures). In some situations it is difficult to separate NetWire log data from other data (for example, when dealing with unallocated space), so NetWire Log Decoder includes logic which fine tunes both carving and parsing in problematic situations.

## NetWire versions tested: ##

NetWire versions 1.6 and 1.7 on Windows and Linux

## Requirements: ##

NetWire Log Decoder uses PowerShell. You can set the appropriate policy (allowing all scripts whether they are signed or not to run) from an administrative PowerShell prompt by entering "Set-ExecutionPolicy Unrestricted". Arsenal recommends only temporarily enabling the "Unrestricted" execution policy, replacing your existing policy when done running NetWire Log Decoder.

## Usage: ##

Input = Either a file or a device. For files, just launch the browse dialog and locate the target file. For devices, a dropdown (populated during startup and can be refreshed at any point later) is provided. When working in command line mode the devices must be specified in a certain format such as;

* F:
* PhysicalDrive3
* Harddisk3Partition1

SkipScan = Skips the entire process of carving (scanning and filtering). Useful when input is an intact NetWire log without any invalid data.
StripInvalid = Attempts to detect invalid data by unresolved keystrokes or other suspicious byte sequences such as 00 or FF. When invalid data is detected, NetWire Log Decoder will jump to the next sector and continue. Typically this setting is useful when you can expect to encounter invalid data, for example when running NetWire Log Decoder against a complete device, volume, or unallocated space.

### Examples: ###

```
netwiredecoder64.exe /Input:D:\temp\02-05-2017 /Mode:file /SkipScan /Output:D:\nwout
netwiredecoder64.exe /Input:D:\temp\merged_output.bin /Mode:file /SkipScan
netwiredecoder64.exe /Input:F: /Mode:device /StripInvalid
netwiredecoder64.exe /Input:Harddisk3Partition1 /Mode:device /StripInvalid
netwiredecoder64.exe /Input:PhysicalDrive2 /Mode:device /StripInvalid
```

## Output files: ##
* netwire_stage1_scanned.bin = Stage 1 output (Sectors with one or more signature hits)
* netwire_stage2_filtered.bin = Stage 2 output (Sectors with five or more signature hits)
* netwire_stage3_decoded.txt = (Final human-friendly output)
* netwire.csv = An ordered listing of unique offsets (sector aligned) used as extract basis
* netwire.log = For verbose logging
* netwire.txt = An unsorted listing of all signature matches


## Notes: ##

**1**
All keystrokes captured in NetWire log data belong to a given window, but identifying the start and end of window information in raw output can be challenging. For that reason, NetWire Log Decoder places markers for the start and end of window information into the output. For example;
```
[new 1 - Notepad++ [Administrator]] - [04/09/2020 15:46:33]
```
becomes;
```
<WINDOW> [new 1 - Notepad++ [Administrator]] - [04/09/2020 15:46:33] </WINDOW>
```
These start and end markers make identification of unique entries in the output easier and helps spot corrupt window information.

**2**
Carving NetWire log data from MFT records can be challenging. During NetWire operation, log data is first written to each new log file's MFT record... at some point becoming too big to fit within the MFT record and turning into non-resident data. When this happens, some of the old log data within the MFT record can be found in MFT record slack. However, there might be some invalid log data at the outer boundary of the MFT record slack. When using NetWire Log Decoder to carve a large volume of input, there may be many examples of this situation. One proposal to handle this situation is;
a) on the NetWire Log Decoder filtered output ("netwire_stage2_filtered.bin") run MftCarver to extract MFT records
b) use Mft2Csv to extract resident data and record slack (which will also remove most of the invalid data that originates from the MFT record itself). This Mft2Csv feature was built specifically for this use case.
c) run merge-resident-extract (available in the same GitHub repository as NetWire Log Decoder) on the folder with the extract from step b above
d) finally re-run the decoder on the merged output file, this time with options /SkipScan active and /StripInvalid deactivated

**3**
In the first stage of processing, NetWire Log Decoder scans and extracts any sector with at least 1 signature hit. In the second stage, NetWire Log Decoder uses validation logic which considers any sector with less than 5 signature hits to be a false positive. In our testing this balance between the first and second stages of processing has worked quite well, but please be aware there will be edge cases where valid NetWire log data is missed in the final (stage 3) output.

**4**
As volumes originating from a Linux system are not possible to mount natively on Windows, we have at least 2 options. One option is to run NetWire Log Decoder against an entire disk image and another is to mount the disk image using Arsenal Image Mounter and run NetWire Log Decoder against a particular partition.

## Contributions: ##

Contributions and improvements to the code are welcomed.

## License: ##

Distributed under the MIT License. See License.md for details.

## More Information: ##

To learn more about Arsenal’s digital forensics software and training, please visit https://ArsenalRecon.com and follow us on Twitter @ArsenalRecon (https://twitter.com/ArsenalRecon).

To learn more about Arsenal’s digital forensics consulting services, please visit https://ArsenalExperts.com and follow us on Twitter @ArsenalArmed (https://twitter.com/ArsenalArmed).