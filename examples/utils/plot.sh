#!/bin/sh

envs() {
    echo "You might have to set these environment variables to adjust the output:"
    echo "FONT       - Font name, comma, then size, like: Arial,10"
    echo "SIZE       - Canvas size; see \"help set term size\" in gnuplot."
    echo "MAINCOLOR  - Color of the plot; either a color name or #rrggbb."
    echo "LMARGIN    - How much space (in %) for text at the left."
    echo "RMARGIN    - How much space (in %) for text on the right."
    echo "BMARGIN    - How much space (in %) for text at the bottom."
    echo "TMARGIN    - How much space (in %) for text on the top."
    echo "KEYWIDTH   - Key width increment; see \"help set key\" in gnuplot."
}

if [ "x$1" = x ]; then
    echo "$0 <data file>"
    printf "Makes a plot.  " # in lieu of echo -n
    envs
    echo "Other options:"
    echo "STYLE    - Set this to \"boxplot\" to get a box plot."
    echo "TITLE    - The title."
    echo "TERMINAL - x11, png, jpg, pdf, etc."
    echo "OUTPUT   - Output file, if applicable."
    echo "PAUSE    - Executed at the end; defaults to \"pause mouse\" if TERMINAL=x11."
    echo "YMAX     - Top of the range of left axis."
    echo "Y2MAX    - Top of the range of right axis."
    exit 0
fi

if [ "x$1" = "x--explain-vars" ]; then
    envs
    exit 0
fi

AWK=${AWK:-awk}

YMAX=${YMAX:-*}
Y2MAX=${Y2MAX:-*}

if [ "x$LMARGIN" = x ]; then
    SET_LMARGIN=
else
    LMARGIN=`${AWK} "BEGIN { print ($LMARGIN / 100) }"`
    SET_LMARGIN="set lmargin ${LMARGIN}"
fi

if [ "x$BMARGIN" = x ]; then
    SET_BMARGIN=
else
    BMARGIN=`${AWK} "BEGIN { print ($BMARGIN / 100) }"`
    SET_BMARGIN="set bmargin ${BMARGIN}"
fi

if [ "x$RMARGIN" = x ]; then
    SET_RMARGIN=
else
    RMARGIN=`${AWK} "BEGIN { print (1 - $RMARGIN / 100) }"`
    SET_RMARGIN="set rmargin ${RMARGIN}"
fi

if [ "x$TMARGIN" = x ]; then
    SET_TMARGIN=
else
    TMARGIN=`${AWK} "BEGIN { print (1 - $TMARGIN / 100) }"`
    SET_TMARGIN="set tmargin ${TMARGIN}"
fi

FONT=${FONT:-Arial,7}

case x$FONT in
    x)    SET_FONT=;;
    *)    SET_FONT="set termoption font '$FONT'";;
esac

case x$TERMINAL in
    x)    SET_TERMINAL="set terminal wxt"
          PAUSE=${PAUSE:-"pause mouse"};;
    xwxt) SET_TERMINAL="set terminal wxt"
          PAUSE=${PAUSE:-"pause mouse"};;
    xx11) SET_TERMINAL="set terminal x11"
          PAUSE=${PAUSE:-"pause mouse"};;
    *)    SET_TERMINAL="set terminal $TERMINAL";;
esac

if [ "x$SIZE" != x ]; then
    SET_TERMINAL="$SET_TERMINAL size $SIZE"
fi

KEY_WIDTH=${KEY_WIDTH:--17}
if [ x$KEY_WIDTH != x ]; then
    SET_KEY_WIDTH="set key width $KEY_WIDTH"
fi

if [ "x$OUTPUT" = x ]; then
    SET_OUTPUT=
else
    SET_OUTPUT="set output '$OUTPUT'"
fi

if [ "x$POINTSIZE" = x ]; then
    SET_POINTSIZE=
else
    SET_POINTSIZE="set pointsize $POINTSIZE"
fi

# Colors of boxes showing time ratios.
MAINCOLOR1=${MAINCOLOR:-red}
MAINCOLOR2=${MAINCOLOR2:-blue}
MAINCOLOR3=${MAINCOLOR3:-green}

# Colors of dots showing C times.
SUBCOLOR1=${SUBCOLOR:-black}
SUBCOLOR2=${SUBCOLOR2:-black}
SUBCOLOR3=${SUBCOLOR3:-black}


Y2LABEL='C running time / repetition [seconds]'
YLABEL='running time: OCaml / C'

SET_COMMON="$SET_TERMINAL; $SET_OUTPUT; $SET_FONT; set title '$TITLE'"
SET_COMMON="$SET_COMMON; $SET_LMARGIN; $SET_RMARGIN; $SET_BMARGIN"
SET_COMMON="$SET_COMMON; $SET_TMARGIN; $SET_KEY_WIDTH; $SET_POINTSIZE"
SET_COMMON="$SET_COMMON; set ytics nomirror; set y2tics nomirror"
SET_COMMON="$SET_COMMON; set ylabel '${YLABEL}' rotate by -90"
SET_COMMON="$SET_COMMON; set y2label '${Y2LABEL}' rotate by -90"
SET_COMMON="$SET_COMMON; set yrange [0:${YMAX}]; set y2range [0:${Y2MAX}]"
SET_COMMON="$SET_COMMON; set xtics rotate by -90 left"

if [ "x$STYLE" = xboxplot ]; then
gnuplot <<EOF
$SET_COMMON
set key inv
set style boxplot sorted

# N = number of data sets
stats "$1" noout
N=STATS_blocks

# Draw vertical lines
set grid xtics lt 0 lw 1 lc rgb "#bbbbbb"

# plot the whole set with boxplot, plot each data set's
# median C time / reps with points
plot "$1" using (0):(\$4/\$5):(0.5):7 with boxplot lc rgb '${MAINCOLOR1}' \
       pointtype 2 \
       title 'OCaml time / C time (left axis)', \
     "$1" using 1:(\$3/\$2) \
       with points pointtype 3 lw 0.5 lc rgb 'black' \
       title 'C time / rep (right axis)' axes x1y2, \
     1 with lines lc rgb '#bbbbbb' notitle, \
     1.5 with lines lc rgb "#bbbbbb" notitle, \
     2 with lines lc rgb '#bbbbbb' notitle
${PAUSE}
EOF
else                            # if STYLE != boxplot, do a bar chart
crunch=`echo $0 | sed -e 's#plot\.sh#crunchperf#'`
gnuplot <<EOF
$SET_COMMON
set key inv

# Bar chart-specific setup
set boxwidth 0.5
set style fill solid

# plot the whole set with boxplot, plot each data set's
# median C time / reps with points
plot "< $crunch -S $1" using 1:5:xticlabels(6) with boxes \
       lc rgb '${MAINCOLOR1}' \
       title 'OCaml time / C time (left axis)', \
     "< $crunch -S $1" using 1:(\$4/\$2) with points pointtype 3 \
       lc rgb 'black' \
       title 'C time / rep (right axis)' axes x1y2, \
     1 with lines lc rgb "#bbbbbb" notitle, \
     1.5 with lines lc rgb "#bbbbbb" notitle, \
     2 with lines lc rgb "#bbbbbb" notitle
$PAUSE
EOF
fi
