
# todo:
# * use a proper build system
# * also allow for native code
# * also allow for generation and dynamic linking of cvode_serial.so

CC=cc
AR=ar
OCAMLC=ocamlc
INCLUDE=`${OCAMLC} -where`

case $1 in
clean)
    rm -f cvode_serial.o cvode_serial_bp.o libcvode_serial.a
    rm -f cvode_serial.cmi cvode_serial.cmo
    rm -f solvelucy.cmi solvelucy.cmo
    rm -f cvode_serial.cma

    rm -f examples/ball.cmi examples/ball.cmo
    rm -f examples/showball.cmi examples/showball.cmo examples/showball.cma
    rm -f examples/sincos.cmi examples/sincos.cmo
    rm -f examples/sincos_lucyf.cmi examples/sincos_lucyf.cmo
    rm -f examples/sincos examples/sincos_lucyf examples/ball
    ;;

*)
    echo "* cvode_serial.c -> cvode_serial.o"
    ${CC} -I $INCLUDE -c cvode_serial.c || exit 1

    echo "* cvode_serial_bp.c -> cvode_serial_bp.o"
    ${CC} -I $INCLUDE -c cvode_serial_bp.c || exit 1

    echo "* cvode_serial.o -> libcvode_serial.a"
    ${AR} rc libcvode_serial.a cvode_serial.o cvode_serial_bp.o || exit 1

    echo "* cvode_serial.mli -> cvode_serial.cmi"
    ${OCAMLC} cvode_serial.mli || exit 1

    echo "* cvode_serial.ml -> cvode_serial.cmo"
    ${OCAMLC} -c cvode_serial.ml || exit 1

    echo "* ... -> cvode_serial.cma"
    ${OCAMLC} -a -o cvode_serial.cma -custom cvode_serial.cmo \
	-cclib -lsundials_cvode \
	-cclib -lsundials_nvecserial \
	-cclib -lcvode_serial || exit 1

    echo "* solvelucy.mli -> solvelucy.cmi"
    ${OCAMLC} solvelucy.mli || exit 1

    echo "* solvelucy.ml -> solvelucy.cmo"
    ${OCAMLC} -c solvelucy.ml || exit 1

    # EXAMPLES

    cd examples/

    echo "* sincos.ml -> sincos"
    ${OCAMLC} -o sincos -I /usr/local/lib -I .. \
	unix.cma bigarray.cma cvode_serial.cma sincos.ml || exit 1

    echo "* sincos_lucyf.ml -> sincos_lucyf"
    ${OCAMLC} -o sincos_lucyf -I /usr/local/lib -I .. \
	unix.cma bigarray.cma cvode_serial.cma solvelucy.cmo sincos_lucyf.ml || exit 1

    echo "* showball.mli -> showball.cmi"
    ${OCAMLC} showball.mli || exit 1

    echo "* showball.ml -> showball.cmo"
    ${OCAMLC} -c showball.ml || exit 1

    echo "* ... -> showball.cma"
    ${OCAMLC} -a -o showball.cma unix.cma graphics.cma showball.cmo || exit 1

    echo "* ball.ml -> ball"
    ${OCAMLC} -o ball -I /usr/local/lib -I .. \
	bigarray.cma unix.cma \
	cvode_serial.cma showball.cma ball.ml || exit 1
    ;;

esac

