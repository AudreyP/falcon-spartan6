//----------------------------------------------------------------------------
//
//		This file is part of the FALCON II.
//
//		The FALCON II is free software: you can redistribute it and/or modify
//		it under the terms of the GNU General Public License as published by
//		the Free Software Foundation, either version 3 of the License, or
//		(at your option) any later version.
//
//		The FALCON II is distributed in the hope that it will be useful,
//		but WITHOUT ANY WARRANTY; without even the implied warranty of
//		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//		GNU General Public License for more details.
//
//		You should have received a copy of the GNU General Public License
//		along with the FALCON II.  If not, see http://www.gnu.org/licenses/.
//
//		The FALCON II is copyright 2008-2010 by Timothy Pearson
//		tpearson@raptorengineeringinc.com
//		http://www.raptorengineeringinc.com
//
//----------------------------------------------------------------------------
//
//		The FALCON II is available as a reference design for the 
//		Raptor Engineering VDFPGA series of FPGA development boards
//		Please visit http://www.raptorengineeringinc.com for more information.
//
//----------------------------------------------------------------------------

parameter InternalClkFrequency = 50000000;							// 50MHz
parameter SlowInternalClkFrequency = InternalClkFrequency / 2;	// 25MHz
parameter WatchDogTimeout = SlowInternalClkFrequency / 2;		// 1/2 of a second

parameter MIN_ERS_CYCLES = 2;
parameter MAX_ERS_CYCLES = 2000;
parameter ERS_CYCLES_PER_ROW = 3048;									// The exposure (shutter open) duration in camera_data_pclk increments
parameter ERS_EXPOSURE_MINIMUM = ERS_CYCLES_PER_ROW * 8;			// Minimum is 8 * T_row
																					// T_row =  2 * max(((W/2)+max(HB, HB_min), (41+346*(Row_Bin+1)+99))
																					// So, my theoretical minimum is 24384

parameter FIB_FPGA_NUMBER = 2;											// Slave FPGA 1
parameter FIRMWARE_VERSION = 0912;

parameter ENUMERATION_ID_1 = 70;
parameter ENUMERATION_ID_2 = 65;
parameter ENUMERATION_ID_3 = 76;
parameter ENUMERATION_ID_4 = 67;
parameter ENUMERATION_ID_5 = 79;
parameter ENUMERATION_ID_6 = 78;
parameter ENUMERATION_ID_7 = 50;
parameter ENUMERATION_ID_8 = 2;
parameter ENUMERATION_ID_9 = 0;
parameter ENUMERATION_ID_10 = 9;
parameter ENUMERATION_ID_11 = 1;
parameter ENUMERATION_ID_12 = 0;

parameter IMAGE_WIDTH=320;
parameter IMAGE_HEIGHT=240;

parameter MAIN_IMAGE_OFFSET=0;
parameter MAIN_GAUSSIAN_IMAGE_OFFSET=76800;
parameter SCALEONE_IMAGE_OFFSET=153600;