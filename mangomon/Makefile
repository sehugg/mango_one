
all: mango1.hex

mango1.hex: mango1.bin

%.bin: %.dasm
	dasm $< -f3 -o$@ -L$*.lst

%.hex: %.bin
	hexdump -e '"" 8/1 "%02x\n" "\n"' $< > $@

