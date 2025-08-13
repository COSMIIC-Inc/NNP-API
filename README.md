# NNP-API Read Me

## Contents
This repository is home to the application programming interface of the COSMIIC System.
Further documentation is available at **[docs.cosmiic.org/Software](https://docs.cosmiic.org/Software)**

## Overview

NNPCORE includes the core functions of the NNP access point (e.g. nnp.transmitAP, nnp.transmit, nnp.read, nnp.write, nnp.nmt)
NNPHELPERS includes everything in NNPCORE + helper functions to do commonly performed tasks (e.g. nnp.networkON)
NNPCHARGER includes everything in NNPHELPERS + charger functionality for COSMIIC charger

normal usage:
nnp = NNPCHARGER; %choose COM port from drop down list, or specify COM port as argument nnp = NNPCHARGER('COM4')
%then use functions as in testCharger.m to operate the charger
e.g. 
nnp.startCoil; %starts coil with default parameters (5V, 3500 Hz) 
% values are specified and returned in real world values (e.g. Volts, Amps,DegreesC where conversions are done in NNPCHARGER)

## Licensing
Firmware and software files are licensed to open source users by COSMIIC under the MIT License. Refer to the **[license text](https://mit-license.org/)** to understand your permissions.

All files of this category are hosted across COSMIIC GitHub repositories. This includes, but is not limited to...

- Firmware
    - Module source code (bootloaders and applications)
    - External wireless components source code (bootloaders and applications)
- Software
    - API in Matlab
    - Assorted Matlab apps
    - Tools and processes, such as custom linters and GitHub Action workflow files
