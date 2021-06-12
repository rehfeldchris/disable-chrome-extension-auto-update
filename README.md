# What

This is a shell script that makes it easy to disable or enable the automatic update process
of all or specific individual Chrome/Chromium extensions. 

# How

Each installed extension has a `manifest.json` file which lists an `update_url` field that Chromium
checks for extension updates. This script will modify that url, adding a `+` character to the front of the url, as a way
to break the update process, preventing it from downloading an extension update. For example, `https://google.com...` will get changed to `+https://google.com...`

# Usage
```
# Download the script
curl -O https://raw.githubusercontent.com/rehfeldchris/disable-chrome-extension-auto-update/master/modupdates.sh
chmod +x modupdates.sh

# Now, edit the installDirSearchBase variable at the top of the script.
# Finally, execute it:
./modupdates.sh
```


# Why

Why disable extension updates? Browser extensions are dangerous. Sometimes, the original extension author will
sell the extension to a new owner with malicious intents, who then updates the extension
to do bad things, like steal your passwords. It may take days or weeks before anyone realizes
the extension has gone rogue, if ever. Even if people notice, and the extension gets taken down, they probably
got at least some of your passwords in that time window.

By disabling the automatic update of certain extensions, it allows you to:   
1) install/update an extension
2) then personally audit the code by viewing the source in the `.crx` file
3) then disable automatic updates again, locking you into a known safe version of the extension

Even if you don't audit the code, by disabling automatic updates, you can search the web to see if 
other users currently have any suspicions about the legitimacy of the extension, and let
other users be the Guinea pigs who install the bleeding edge versions of the extensions, while you 
continue to use older proven versions until the latest version has been out for a while without drawing complaints.


# Supported Browsers

It should work for all Chrome and Chromium-based browsers. It will automatically handle multiple browser installs,
for example like when you install multiple chrome release channels such as Stable, Beta, Dev, Canary etc... 

For other Chromium based browsers (i.e. Vivalid, Brave, Edge etc...), you may need to edit the `installDirSearchBase` variable to point to where the
browser keeps installed extension metadata on your specific filesystem.


# Supported Platforms

windows  
linux  
mac  

Of course, you also need something like `bash` to run the script. Windows users should consider
something like Windows Subsystem for Linux (WSL), Cygwin, or Git Bash / MSYS2 etc...

# Who

This is intended to be used by power users, in particular users who are capable of running shell
scripts. You should also be able to read shell scripts, mainly to ensure you're not running some 
malicious code. For security reasons, don't blindly execute shell scripts you find on the 
internet unless you can audit the code, or someone you trust audits it for you.

# Contributing

Pull requests are welcome.