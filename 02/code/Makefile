# 顶层 Makefile: 代理到 boot 子目录

SUBDIR := boot

.PHONY: all run debug clean analyze info help

all run debug analyze info help:
	@$(MAKE) -C $(SUBDIR) $@

clean:
	@$(MAKE) -C $(SUBDIR) clean
