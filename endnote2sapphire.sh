#!/bin/bash
# This script will reformat an XML exported from Endnote into the correct format for Sapphire.
# It does two main things: (1) fixes the Dates, and (2) truncates the author address to max 255 characters
#
# # Dates
# NHMRC Sapphire can import XML files from Endnote, but it will only parse the date correctly if it's of the form DD-MMM-YYYY (https://healthandmedicalresearch.gov.au/data.html?data=endnote)
# Unfotunately, Endnote X9 records only "Mmm", "Mmm D" or "Mmm DD" in the Date field & the year is stored separately.
# Endnote 20 also seems to have the same behaviour. I've only tested this on a mac, so YMMV on PC.
#
# # overly long authAddress:
# A common warning when importing an Endnote XML is regarding overly long authAddress (>255 chars). The records are imported over-sized and then if you ever manually edit the record in Sapphire you'll be forced to shorten them. This utility truncates these to 255 characters. This script ensures that the record is at most 255 characters long, but since some special characters are escaped in the XML file (e.g. ' is &apos;), the final length in Sapphire may be shorter than 255 characters.
#
# In Endnote you should:
# 1. [optional] select citations and make sure the references are up-to-date, via "Find Reference Updates..." and 'update all fields'. This will sync with PubMed. Beyond updating the Year, Volume and Issue, this ensures that the author names are consistent Surname, A.B.C.
# 2. Make sure the year field is filled in. This should be a 4-digit number & records without this will be not get updated.
# 3. Export the references via File > Export > "File type: XML, Output Style: annotated"
# 4. run this script on the XML, which will update it inline.
# In Sapphire, you should:
# 5. delete any records from Sapphire that need to be overwritten.
# 6. import the XML: Profile > publications > import from endnote button
# 7. carefully read the import warnings and errors. this script has no warranty!
#    Common warnings included:
#    * (2) same for overly long keywords sections.
#    * (3), and if the page range is 125-8, then you'll get an 'end page is < start page' warning, but it still imports them ok & is still human readable.
#
# usage: $endnote2sapphire.sh <exported_from_endnote.xml>
#
# TODO
# * truncate keywords to 500 chars - need a clever way to sum the length of <keyword> tokens within their XML tags.
# * better regex to capture custom <style> within <year/style> and <date/style> - only if this turns out to be a problem (eg if someone has customised this in their EndNote config.)
# * fix page range (eg 123-9 to 123-129) - not much point as Sapphire warns, but otherwise handles this ok.
# * make the address exactly 255 chars after the escaped characters are un-escapted in Sapphire - quite tricky, for very little benefit.
#
# Mark Cowley, 7/3/2021

function usage () {
  echo >&2 "$0 references_exported_from_endnote.xml"
}

# cause execution to terminate, with an optional message,
# and optional error code.
# $1: optional error message
# $2: optional error code. default = 1
function die () {
	msg="######### ABORTING: ${1-Unexpected error}"
	exitcode=${2-1}
	echo >&2 "$msg"
	exit $exitcode
}

(($# == 1)) || die "must supply exactly 1 arguments"

f="$1"
[[ -f "$f" ]] || die 
[[ $(file -b --mime-type "$f") == "text/xml" ]] || die "file does not appear to be an XML file"

# Fix Date field
## "Feb" -> "01-Feb-YYYY"
perl -pi -e 's|<year><style face="normal" font="default" size="100%">([0-9]{4})</style></year><pub-dates><date><style face="normal" font="default" size="100%">([A-Z][a-z][a-z])</style>|<year><style face="normal" font="default" size="100%">$1</style></year><pub-dates><date><style face="normal" font="default" size="100%">01-$2-$1</style>|g' "${f}"
## "Feb 5" -> "05-Feb-YYYY"
perl -pi -e 's|<year><style face="normal" font="default" size="100%">([0-9]{4})</style></year><pub-dates><date><style face="normal" font="default" size="100%">([A-Z][a-z][a-z]) ([1-9])</style>|<year><style face="normal" font="default" size="100%">$1</style></year><pub-dates><date><style face="normal" font="default" size="100%">0$3-$2-$1</style>|g' "${f}"
## "Feb 12" -> "12-Feb-YYYY"
perl -pi -e 's|<year><style face="normal" font="default" size="100%">([0-9]{4})</style></year><pub-dates><date><style face="normal" font="default" size="100%">([A-Z][a-z][a-z]) ([0-9][0-9])</style>|<year><style face="normal" font="default" size="100%">$1</style></year><pub-dates><date><style face="normal" font="default" size="100%">$3-$2-$1</style>|g' "${f}"
## "" -> "01-Jan-YYYY"
perl -pi -e 's|<year><style face="normal" font="default" size="100%">([0-9]{4})</style></year><pub-dates><date><style face="normal" font="default" size="100%"></style>|<year><style face="normal" font="default" size="100%">$1</style></year><pub-dates><date><style face="normal" font="default" size="100%">01-Jan-$1</style>|g' "${f}"

# truncate authAddress
perl -pi -e 's|(<auth-address><style [^>]+>)([^<]{255})[^<]*(</style></auth-address>)|$1$2$3|g' "${f}"
# sometimes, this naive approach to truncation can interrupt an escaped character sequence.
# These are the XML escape sequences:
# Original character	Escaped character
#   "	                  &quot;
#   '	                  &apos;
#   <	                  &lt;
#   >	                  &gt;
#   &	                  &amp;
#   ;	                  &#xD;
# i've translated these to this regex, which will trim off any truncated escaped character from the <auth-address> field
perl -pi -e 's|(&?[qalg#]?[uptmx]?[o;pD]?[ts;]?;?)(</style></auth-address>)|$2|g' "${f}"

# # sometimes, truncation can interrupt an escaped character sequence
# # fix an odd formatting thing often in the <notes> section
# perl -pi -e 's|&#xD;|;|g' "${f}"
# perl -pi -e "s|&apos;|'|g" "${f}"
# perl -pi -e "s|&amp;|&|g" "${f}"
