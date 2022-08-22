module lf2.encryption;

const char[] lf2CryptoKey = "SiuHungIsAGoodBearBecauseHeIsVeryGood";

char[] decryptLf2Data(const(char)[] data, const(char)[] key = lf2CryptoKey, size_t additionalNonsense = 123)
{
	return cast(char[])decryptLf2Data(cast(const(ubyte)[])data, cast(const(ubyte)[])key, additionalNonsense);
}

ubyte[] decryptLf2Data(const(ubyte)[] data, const(ubyte)[] key = cast(ubyte[])lf2CryptoKey, size_t additionalNonsense = 123)
{
	if (data.length <= additionalNonsense)
		return null;
	
	ubyte[] result = new ubyte[data.length - additionalNonsense];
	
	for (size_t i = 0; i < result.length; i++)
		result[i] = cast(ubyte)(data[i + additionalNonsense] - key[(i + additionalNonsense) % $]);
	
	return result;
}

char[] encryptLf2Data(const(char)[] data, const(char)[] key = lf2CryptoKey, size_t additionalNonsense = 123)
{
	return cast(char[])encryptLf2Data(cast(const(ubyte)[])data, cast(const(ubyte)[])key, additionalNonsense);
}

ubyte[] encryptLf2Data(const(ubyte)[] data, const(ubyte)[] key = cast(ubyte[])lf2CryptoKey, size_t additionalNonsense = 123)
{
	ubyte[] result = new ubyte[data.length + additionalNonsense];
	
	for (size_t i = 0; i < additionalNonsense; i++)
		result[i] = ubyte.max;
	
	for (size_t i = additionalNonsense; i < result.length; i++)
		result[i] = cast(ubyte)(data[i] + key[i % $]);
	
	return result;
}
