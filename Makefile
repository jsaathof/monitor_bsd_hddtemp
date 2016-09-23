PODSELECT=/usr/local/bin/podselect

readme:
	$(PODSELECT) monitor_bsd_hddtemp.pl > README.pod

all:
	readme
