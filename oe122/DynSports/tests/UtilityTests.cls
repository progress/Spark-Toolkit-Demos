/*------------------------------------------------------------------------
    File        : UtilityTests
    Purpose     :
    Syntax      :
    Description :
    Author(s)   : dugrau@progress.com
    Created     : Thu May 30 19:10:52 EDT 2017
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class tests.UtilityTests inherits tests.SparkUnit:

    define private variable hCPO as handle no-undo.

    /*------------------------------------------------------------------------------
     Purpose: Start up the Spark stack similar to a session of the MSAS agent.
     Notes:
    ------------------------------------------------------------------------------*/
    @Before.
    method public void before ( ):
        this-object:StartSpark("utility").
    end method.

    /*------------------------------------------------------------------------------
     Purpose: Shut down the Spark stack similar to a session of the MSAS agent.
     Notes:
    ------------------------------------------------------------------------------*/
    @After.
    method public void after ( ):
        this-object:StopSpark().

        finally:
            delete object hCPO no-error.
        end finally.
    end method.

    /*------------------------------------------------------------------------------
        Purpose:
        Notes:
    ------------------------------------------------------------------------------*/
    @Setup.
    method public void setUp ( ):
    end method.

    /*------------------------------------------------------------------------------
        Purpose:
        Notes:
    ------------------------------------------------------------------------------*/
    @TearDown.
    method public void tearDown ( ):
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the binary to integer conversions work.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testBinaryIntegerConversion ( ):
        define variable cTest as character no-undo extent 2048.
        define variable iX    as integer   no-undo.

        /* Test for zero. */
        OpenEdge.Core.Assert:Equals(0, Spark.Core.Util.Convert:BinToInt("0")).

        do iX = 1 to extent(cTest):
            /* Convert an integer value to a binary string. */
            assign cTest[iX] = Spark.Core.Util.Convert:IntToBin(iX).
        end.

        do iX = 1 to extent(cTest):
            /* Convert each binary string back to integer, which should match the original. */
            OpenEdge.Core.Assert:Equals(iX, Spark.Core.Util.Convert:BinToInt(cTest[iX])).
        end.
    end method.


    /*------------------------------------------------------------------------------
        Purpose: Confirm the integer to hexadecimal conversions work.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testIntegerHexadecimalConversion ( ):
        define variable cTest as character no-undo extent 2048.
        define variable iX    as int64     no-undo.

        /* Test for zero. */
        OpenEdge.Core.Assert:Equals("0", Spark.Core.Util.Convert:IntToHex(0)).

        do iX = 1 to extent(cTest):
            /* Convert an integer value to a hexadecimal string. */
            assign cTest[iX] = Spark.Core.Util.Convert:IntToHex(iX).
        end.

        do iX = 1 to extent(cTest):
            /* Convert each hex string back to integer, which should match the original. */
            OpenEdge.Core.Assert:Equals(iX, OpenEdge.Core.Util.MathUtil:HexToInt(cTest[iX])).
        end.
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the binary to hexadecimal conversions work.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testBinaryHexadecimalConversion ( ):
        define variable cTest as character no-undo extent 2048.
        define variable iX    as int64     no-undo.

        /* Test for zero. */
        OpenEdge.Core.Assert:Equals("0", Spark.Core.Util.Convert:BinToHex("0")).

        do iX = 1 to extent(cTest):
            /* Convert an integer value to a binary string. */
            assign cTest[iX] = Spark.Core.Util.Convert:IntToBin(iX).
            /* Convert a binary string to a hexadecimal string. */
            assign cTest[iX] = Spark.Core.Util.Convert:BinToHex(cTest[iX]).
        end.

        do iX = 1 to extent(cTest):
            /* Convert each hex string back to integer, which should match the original. */
            OpenEdge.Core.Assert:Equals(iX, OpenEdge.Core.Util.MathUtil:HexToInt(cTest[iX])).
        end.
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the Base32 encode works.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testBase32Encode ( ):
        /* Encoded value should match a known value. */
        OpenEdge.Core.Assert:Equals("JBSWY3DPEFLW64TMMQQQ====", Spark.Core.Util.Base32:EncodeData("Hello!World!")).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the Base32 decode works.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testBase32Decode ( ):
        /* Decoded value should match a known value. */
        OpenEdge.Core.Assert:Equals("Hello!World!", Spark.Core.Util.Base32:DecodeData("JBSWY3DPEFLW64TMMQQQ====")).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the Base32 encode/decode works together.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testBase32 ( ):
        define variable cOriginal as character no-undo initial "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".
        define variable cEncoded  as character no-undo.
        define variable cDecoded  as character no-undo.

        /* Encode and decode the given original value. */
        assign cEncoded = Spark.Core.Util.Base32:EncodeData(cOriginal).
        log-manager:write-message(substitute("Base32-Encoded &1 as &2", cOriginal, cEncoded)).
        assign cDecoded = Spark.Core.Util.Base32:DecodeData(cEncoded).
        log-manager:write-message(substitute("Base32-Decoded &1 as &2", cEncoded, cDecoded)).

        /* Encoded-Decoded value should match the original. */
        OpenEdge.Core.Assert:Equals(cOriginal, cDecoded).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the Base32 conversion to hex works.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testBase32Hex ( ):
        /* Converted value should match a known value. */
        OpenEdge.Core.Assert:Equals("48656c6c6f21deadbeef", Spark.Core.Util.Base32:ConvertToHex("JBSWY3DPEHPK3PXP")).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the HMAC algorithm works.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testHMAC ( ):
        define variable cHash as character no-undo.

        /* Should reuse the hex value from testBase32Hex, and a known timestamp as 16-digit padded hex. */
        assign cHash = Spark.Core.Security.HMAC:GenHash("SHA-1", "48656c6c6f21deadbeef", "0000000002ff7d1e").

        /* Calculated value from 2 known factors should match a known value. */
        OpenEdge.Core.Assert:Equals("5b56f711bf9e0c4b77850caaafe34e89b5ec55c8", cHash).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the HMAC truncation works.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testHMACTruncation ( ):
        define variable iTrunc as int64     no-undo.
        define variable cTrunc as character no-undo.

        /* Should reuse hash from testHMAC, testing only the truncation to an integer. */
        assign iTrunc = Spark.Core.Security.HMAC:TruncateHMAC("5b56f711bf9e0c4b77850caaafe34e89b5ec55c8").

        /* Reduce the truncated integer to a 6-digit code. */
        assign cTrunc = string(iTrunc modulo exp(10, 6)).
        if length(cTrunc) lt 6 then /* Left-pad with zeroes if too short. */
            assign cTrunc = substitute("&1&2", fill("0", 6 - length(cTrunc)), cTrunc).

        /* Calculated value from 2 known factors should match a known value. */
        OpenEdge.Core.Assert:Equals("208234", cTrunc).
    end method.

end class.