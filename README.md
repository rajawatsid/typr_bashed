# tty_wpm_bashed
for Bashed YSWS by HackClub

The purpose of this is to make a [monkeytype](monkeytype.com) clone but on a terminal user interface. 
I think it should make it so that the user can type from a random assortment of words and it will record how long it takes them to type. It can also store previous session data in their machine and it will give comparisons based on time and date.

first we will make a set word and then it should type using that.

## some sources
Got the word list using:
```
curl -L https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english.txt \
    -o english.txt
```

## file structure to make
```
typr/
├── typr                  # main executable (entry point)
├── lib/
│   ├── ui.sh             # colors, cursor control, drawing, centering
│   ├── input.sh          # key reading, escape sequences, backspace handling
│   ├── game.sh           # the test loop, timer, scoring logic
│   ├── words.sh          # loading word lists, picking random words
│   ├── stats.sh          # WPM/accuracy math, saving and reading history
│   ├── menu.sh           # menu and settings screens
│   └── config.sh         # defaults, loading/saving user settings
├── words/
├── tests/
│   └── test_stats.sh     # quick checks for your math functions
├── install.sh            
├── README.md
├── LICENSE
└── demo.gif
```