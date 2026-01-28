
// library made by greggg04

I16 RandI16Range(I16 min, I16 max)
{
  I16 number = min + RandI16() % (max - min + 1);
  return number;
}

U16 RandU16Range(U16 min, U16 max)
{
  U16 number = min + RandU16() % (max - min + 1);
  return number;
}

I32 RandI32Range(I32 min, I32 max)
{
  I32 number = min + RandI32() % (max - min + 1);
  return number;
}

U32 RandU16Range(U32 min, U32 max)
{
  U32 number = min + RandU32() % (max - min + 1);
  return number;
}


I64 RandI64Range(I64 min, I64 max)
{
  I64 number = min + RandI64() % (max - min + 1);
  return number;
}

U64 RandU64Range(U32 min, U32 max)
{
  U64 number = min + RandU64() % (max - min + 1);
  return number;
}

