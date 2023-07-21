#Robert Grumbine 27 May 2016
SHELL=/bin/sh
        
include makeall.mk

NCEPLIB=$(BUFR_LIB4) $(W3EMC_LIB4) $(W3NCO_LIB4)

#Should be no changes below this point---------------------------------

all : ssmisu_tol2 

ssmisu_tol2 : ssmisu_algorithm.o filter.o bufr.o skel.o ssmisu_decode.o
	$(FC) ssmisu_decode.o filter.o skel.o bufr.o ssmisu_algorithm.o  -L $(NETCDF_LIBRARIES) -lnetcdf  $(NCEPLIB) $(LIBS) -o $(@)


# ---------------------------------------------------------------------
clean :
	rm *.o

# ---------------------------------------------------------------------
