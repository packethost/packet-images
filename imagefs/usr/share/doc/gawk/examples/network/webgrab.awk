BEGIN { RS = "https?://[#%&\\+\\-\\./0-9\\:;\\?A-Z_a-z\\~]*" }
RT != "" {
   command = ("gawk -v Proxy=MyProxy -f geturl.awk " RT \
               " > doc" NR ".html")
   print command
}
