# TurboPower Object Professional v1.30

22 years ago, TurboPower Software closed their doors as a retail software company and released all of their development libraries the for Borland[1]/CodeGear/Embarcadero Delphi compiler.  These items were released under a Mozilla 1.1 license.

Here's their original announcement: http://www.turbopower.com/

Unfortunately, nobody seems to have been able to get their attention about making their fantastic MS-DOS libraries for Turbo Pascal available online.

Their website clearly states, "TurboPower libraries released as open source".  Their MS-DOS libraries would appear to fall under that statement.  Maybe they figured, "Hey, it's 2003. Nobody's going to be interested in this ancient DOS stuff!"

Well dammit, **I'm** interested!  I'm sure I'm not the only one.

I owned a copy of Object Professional that I used back in the mid 90's and after chasing down some patch updates, this repository is the result.  At some point, I'll be adding photos and binary images of my original diskettes.

## Building
Object Professional can be built using Turbo Pascal versions 5.5 to 7.0, and Borland Pascal v7.0.  In the case of Borland Pascal 7.0, units can be built for both real mode (TPU) and protected mode (TPP).  The build process also requires Turbo Assembler v1.0 or greater, or Microsoft Assembler v4.0 or greater in order to assemble the .ASM files.  You'll need to ensure that your build tools are in your DOS path.

The file SRC\OPDEFINE.INC has settings that can be changed in order to affect how Turbo Power is built and functions.  It would be worth your time to peruse that file - note that unless you know **why** you're going to change something, you probably should leave it the default.

The Makefile for Object Professional can be found in SRC\OPRO.MAK.  This file will allow you to adjust a number of different things about how the units are built.  I recommend going through it - the settings it uses are very well documented.  Note that the Makefile uses the Borland Make syntax.

There are three directory assignments in the Makefile that you'll need to change:

* asmdir - the location of the assembly code files.  
* tpudir - the location of the Turbo Pascal source code.
* demodir - the location of the Turbo Pascal source code for the demos.

The directory assignments must be full paths - relative paths confuses Borland's make program.

Change to the SRC directory and kick off the build with `MAKE -FOPRO`.  This will build all the units, all the object files, compile the help files, and build all the examples.  Copy all the TPU and/or TPP unit files to some location that you can easily point the compiler's Unit Directory setting at.  You're done!

## Documentation

The Object Professional documentation is spread across three volumes:
* Vol. 1 - Screen Management
* Vol. 2 - Data Input/Output
* Vol. 3 - TSRs and More

I'll be scanning all three volumes and updating them as soon as possible.

Hopefully more people than just me will find this repository useful.




