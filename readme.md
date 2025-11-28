# c4x -- the neovim compiler explorer
I use godbolt's compiler explorer quite often but copy pasting the code bits 
over every time is not only cumbersome, its also not recommended to do for 
proprietary code bases.

Thats why I created this plugin, which allows you to inspect the codegen of
files you track. It spawn a panel on the right side of the current buffer 
which can be navigated left and right. the printing logic is quite naive so
if you take more space than the standard 80 characters width it might lead 
to issues.

Currently it only supports x86-64 gcc (and only the version you have 
installed locally), changing this to be more dynamic is trivial. the reason
I didnt implement it is because I dont need it (yet).

## planned features

- [ ] comparision feature, allowing you to compare codegen of two different files

- [ ] git integration, allowing you to compare codegen across branches

- [ ] clipped line printing for the tabs in the panel

- [ ] generic compiler infrastructure (supporting clang and maybe also cargo or g++)

- [ ] command block, that allows you to change the extra compiler flags on the fly.

- [ ] asynchronous io so that big compiles dont block the user experience (specially for c++ and rust)

- [ ] better modularity for keybinds etc.
