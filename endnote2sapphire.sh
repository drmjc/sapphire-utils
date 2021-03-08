#!/bin/bash
# NHMRC Sapphire can import XML files from Endnote, but it will only parse the date correctly if it's of the form DD-MMM-YYYY (https://healthandmedicalresearch.gov.au/data.html?data=endnote)
# Unfotunately, Endnote X9 records only "Mmm", "MMM D" or "Mmm DD" in the Date field & the year is stored separately.
# Endnote 20 also seems to have the same behaviour. I've only tested this on a mac, so YMMV on PC.
#
# This script will convert the dates from an XML exported from Endnote into the correct format.
#
# In Endnote you should:
# 1. [optional] select citations and make sure the references are up-to-date, via "Find Reference Updates..." and 'update all fields'. This will sync with PubMed. Beyond updatign the Volume and Issue, this ensures that the author names are consistent Surname, Initials.
# 2. [optional] make sure the Date field has something in it. Some articles are are just from a Year, so put Jan, or Jan 1 in there.
# 3. Make sure the year field is filled in. This should be a 4-digit number & records without this will be not get updated.
# 4. Export the references via File>Export> "File type: XML, Output Style: annotated"
# 5. run this script on the XML, which will update it inline.
# In Sapphire, you should:
# 6. delete any records from Sapphire that need to be overwritten.
# 7. import the XML: Profile > publications > import from endnote button
# 8. carefully read the import warnings and errors. this script has no warranty!
#    Common warnings included:
#    * (1) overly long authAddress (>500 chars): these get imported over-sized and then if you ever manually edit the record in Sapphire you'll be forced to shorten them. [update: this should now be fixed]
#    * (2) same for overly long keywords sections.
#    * (3), and if the page range is 125-8, then you'll get an 'end page is < start page' warning, but it still imports them ok & is still human readable.
#
# usage: $endnote2sapphire.sh <exported_from_endnote.xml>
#
# TODO
# * truncate keywords to 500 chars - need a clever way to sum the length of <keyword> tokens within their XML tags.
# * better regex to capture custom <style> within <year/style> and <date/style> - only if this turns out to be a problem (eg if someone has customised this in their EndNote config.)
# * fix page range (eg 123-9 to 123-129) - not much point as Sapphire warns, but otherwise handles this ok.
#
# MJC, 7/3/2021

function usage {
  echo >&2 "$0 references_exported_from_endnote.xml"
}
function die {
  usage
  exit 1
}

f="$1"
[[ -f "$f" ]] || die 

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
perl -pi -e 's|(<auth-address><style [^>]+>)([^<]{500})[^<]*(</style></auth-address>)|$1$2$3|g' "${f}"

# fix an odd formatting thing often in the <notes> section
perl -pi -e 's|&#xD;|;|g' "${f}"