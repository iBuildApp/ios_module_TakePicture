headerdoc2html -j -o mTakePicture/Documentation mTakePicture/mTakePicture.h     


gatherheaderdoc mTakePicture/Documentation


sed -i.bak 's/<html><body>//g' mTakePicture/Documentation/masterTOC.html
sed -i.bak 's|<\/body><\/html>||g' mTakePicture/Documentation/masterTOC.html
sed -i.bak 's|<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">||g' mTakePicture/Documentation/masterTOC.html