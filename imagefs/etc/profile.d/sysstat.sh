# Enable color output of sar(1) command
if [ -z "${S_COLORS-}" ]; then
  S_COLORS=auto
  export S_COLORS
fi
