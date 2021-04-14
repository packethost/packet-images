# pi.awk --- compute the digits of pi
#
# Katie Wasserman, katie@wass.net
# August 2014

BEGIN {
    digits = 100000
    two = 2 * 10 ^ digits
    pi = two
    for (m = digits * 4; m > 0; --m) {
        d = m * 2 + 1
        x = pi * m
        intdiv0(x, d, result)
        pi = result["quotient"]
        pi = pi + two
    }
    print pi
}
