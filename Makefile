

all: doc

doc: setnet.8
	gzip -c setnet.8 > setnet.8.gz
	groff -m mdoc -T html setnet.8 > setnet.8.html
