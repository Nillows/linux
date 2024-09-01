# Here are my custom linux functions and alias' so that I can curl them to any VM I want, whenever I want with

## 'curl -L https://nillows.github.io/linux/ >> ~/.bashrc'

## The 'back' function
Uses a modified 'cd' command to store visited directories in an array and increment a variable to track the array length

Invoked with 'back' to automatically decrement the variable, 'cd' to the penultimate directory in the array, and then truncate the path array.
