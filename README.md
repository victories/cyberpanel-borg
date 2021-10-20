# Motivation - What does this project try to solve
I liked cyberpanel and I wanted to have more control over the backup / restore procedure.
This project offers basic features that I was missing from the cyberpanel backup implementation and they are really important for me!
1. Backup and restore child domains of a website individually (e.g. what would happen if you wanted to restore only a child domain? Via cyberpanel you only get the option to restore the whole websites' data)
2. Backup and restore email accounts of a website individually instead of restoring all accounts at once.
3. Configurable ssh location for backups with support for Hetzner storageboxes that I love to use. Btw, if you would like to try Hetzner Cloud here is [my referral link](https://hetzner.cloud/?ref=6L5jCPv0bcf5). When you sign up for their cloud services you will receive €20 in cloud credits. (StorageBox is not part of the cloud service but VMs are 😉)

# What this project does NOT offer
1. A simple to use UI. The backup restore scripts are not accessible from the Cyberpanel UI but only via terminal. I am not aware of how I can embed them (not a python expert 😇) and I will not go through the effort anytime soon. (Contributors that can implement that are of course welcome to create a pull request)

# Prerequisites
1. Install borg. Details here: [Borg Install Docs](https://borgbackup.readthedocs.io/en/stable/installation.html)
2. Install mailx. Details here: [Install mailx command](https://www.atechtown.com/install-mailx-on-linux/#install-mailx-on-linux)

# Limitations
The only known limitation is that you cannot restore a db / domain / email if that doesn't exist in cyberpanel. You have to create first the db / domain / email that you want to restore if that doesn't exist in the panel. I have taken into account this cases and the scripts will show a message to warn you.
