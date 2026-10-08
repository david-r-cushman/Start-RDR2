# Start-RDR2

## Purpose

A PowerShell 5.1 script to launch RDR2 and automatically set the game process to run in efficiency mode

The plan here will be to create a PowerShell script that launches RDR2, waits for the game process (RDR2.exe) to be running, and then automatically sets the running
process to run in Efficiency mode.

## Why

Many players on newer hardware have noticed that the game performs extremely poorly, fails to load textures, crashes etc., and that the easiest fix available is to
launch the game, and then through the Windows Task Manager, locate the game process, right click, and select "Efficiency Mode." The challenge is, is that this is a
PITA as this must be done every single time the game is luanched.

This script will aim to fix that.

Additionally, the script will be documented extremely well, and with the intention of guiding the user of the script in to the world of PowerShell automation by
demonstrating to them how it can resolve a problem that they are actually aware of and care about - enjoying their game, and removing as much friction from their path
while they do so.

The readme should be very robust, easy to follow, and guide the user through all perceived steps that will be needed to utilize the script, including the assumption that not only
are they not familiar with PowerShell, they are likely not familiar with GitHub, the process of cloning repos etc. We'll keep it as simple as possible, and just have them download
the necessary folders to a standardized local folder, such as C:\Scripts. We'll then of course also need to assume that they don't understand how to run PowerShell scripts, or
work with PowerShell's execution policy, and to facilitate this we'll likely also produce a batch file that can simply be double clicked to launch the script itself.

All steps will be clearly documented, and of course the .ps1 and .bat files can be inspected to ensure that no unsafe actions are being performed. We'll likely even suggest that
the user copy and paste the file contents in to an AI chatbot such as ChatGPT, Gemini etc., and ask for a review of the code and recommendation on what the code does, and if there
are any safety concerns in running it.
