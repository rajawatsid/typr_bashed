# tty_wpm_bashed
for Bashed YSWS by HackClub

The purpose of this is to make a [monkeytype](monkeytype.com) clone but on a terminal user interface. 
I think it should make it so that the user can type from a random assortment of words and it will record how long it takes them to type. It can also store previous session data in their machine and it will give comparisons based on time and date.

first we will make a set word and then it should type using that.

Got the word list using:
```
curl -L https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-no-swears.txt \
    -o words/english.txt
```

## to install latest version
```
curl -fsSL https://github.com/rajawatsid/typr_bashed/releases/latest/download/install.sh | bash
```