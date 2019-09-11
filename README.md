Mango One
=====

A simple 6502-based computer inspired by the Apple I, implemented in Verilog.

For the 6502 CPU, we use an [open-source model](https://github.com/Arlet/verilog-6502)
created by Arlet Ottens.

The Mango One's memory map is very similar to the Apple I:

Start | End      | Description
------|----------|----------
$0000 | $0FFF    | RAM
$A000 | $CFFF    | Expansion ROM
$D010 | $D013    | 6821 PIA (keyboard, terminal)
$FF00 | $FFFF    | Monitor ROM, CPU vectors

The monitor program in ROM, MangoMon, is a custom 256-byte monitor ROM with just a few commands:

Command   | Function
----------|----------------------
`R` `aaaa`      | Dump memory at address $aaaa
Enter           | Dump next 8 bytes
`W` `aaaa` `bb` | Write byte $bb at address $aaaa
`G` `aaaa`      | Jump to address $aaaa

You can [open this project in 8bitworkshop](http://8bitworkshop.com/redir.html?platform=verilog&githubURL=https%3A%2F%2Fgithub.com%2Fsehugg%2Fmango_one&file=mango1.v) and try it out!

