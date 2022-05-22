// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

library WadLib {
    uint256 public constant MULTIPLIER = 10**18;

    // GAS NOT OPTIMISED WHEN USING STRUCT
    // struct Wad {
    //     uint256 value;
    // }

    // GAS OPTIMISED WAY WHEN USING CUSTOM TYPE
    type Wad is uint256;

    function mulWad(uint256 number, Wad wad) internal pure returns (uint256) {
        return (number * Wad.unwrap(wad)) / MULTIPLIER;
    }

    function divWad(uint256 number, Wad wad) internal pure returns (uint256) {
        return (number * MULTIPLIER) / Wad.unwrap(wad);
    }

    function fromFraction(uint256 numerator, uint256 denominator)
        internal
        pure
        returns (Wad)
    {
        if (numerator == 0) {
            return Wad.wrap(0);
        }
        return Wad.wrap((numerator * MULTIPLIER) / denominator);
    }
}
