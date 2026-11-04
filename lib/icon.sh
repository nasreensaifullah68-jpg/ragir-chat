sudo apt-get update -qq
sudo apt-get install -y librsvg2-bin
rsvg-convert -w 1024 -h 1024 icon.svg -o icon.png
grep -v 'id="bg"' icon.svg > fg.svg
rsvg-convert -w 1024 -h 1024 fg.svg -o icon_fg.png
dart run flutter_launcher_icons
sed -i 's/android:label="[^"]*"/android:label="Rahgeer Chat"/' android/app/src/main/AndroidManifest.xml
echo "icon step finished"
exit 0
