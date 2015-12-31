#!/bin/sh

if [ -d /media/F9B9-FF2F ]; then
	zenity --question --text="Синхронизировать InstaPaper на PocketBook?" && \
	$HOME/work/instabook/instabook.pl --username INSTAPAPER-LOGIN --destdir /media/F9B9-FF2F/instapaper --password INSTAPAPER-PASSWD && \
	notify-send 'InstaPaper синхронизирован'
else
	zenity --warning --text="/media/F9B9-FF2F недоступен"
fi
