# chip8-zig
A Chip8 emulator in Zig

# apropos
This is my first emulator ever  
Not working yet ^^

# test
The file `./hex.content` contains each different calls:  
```bash
$ xdd ./hex.content
00000000: 0222 00e0 00ee 1333 2444 3655 4566 5be0  .".....3$D6UEf[.
00000010: 6c23 7c23 8cd0 8cd1 8cd2 8cd3 8cd4 8cd5  l#|#............
00000020: 8cd6 8cd7 8cde 9cd0 a234 b234 c423 d456  .........4.4.#.V
00000030: ea9e eba1 fc07 fd0a fe15 fa18 fb1e fc29  ...............)
00000040: fd33 fe55 f265                           .3.U.e
```

# todo
[X] Load file to ram
[X] Fetch opcode
[X] Decode opcode
[ ] Execute opcode
[ ] Display (virtual screen)
[ ] Input (virtual keyboard)
