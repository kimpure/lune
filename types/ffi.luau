--[=[
	@class FFI
	
	Built-in library for foreign function interface.

	### Example usage
	lib.c:
	```c
	int add(int a, int b) {
		return a + b;
	}
	```
	init.luau:
	```lua
	local ffi = require("@lune/ffi")

	-- Create function signature
	local addSignature = ffi.c.fn({ ffi.c.int, ffi.c.int }, ffi.c.int)

	-- Load library
	local lib = ffi.open("./lib.so")

	-- Get symbol from library
	local addSymbol = lib:find("add")

	-- Create CallableData
	local add = addSignature:callable(addSymbol)

	-- Create result box and arguments
	local result = ffi.box(ffi.c.int.size)
	local a = ffi.c.int:box(1)
	local b = ffi.c.int:box(2)
	
	-- Call external function
	add(result, a:ref(), b:ref())

	-- Get number from result
	print(ffi.c.int:readData(result))
	```
]=]
local ffi = {}

--[=[
	@class C

	Namespace for compile time sized c types.
]=]
local c = {}
ffi.c = c

--#region Data
--[=[
	@class RefData
	
	A user manageable memory reference.
]=]
export type RefData = {
	--[=[
		@within RefData
		@tag Method
		@method deref

		Get a RefData by dereference this reference.

		@return A dereferenced `RefData`
	]=]
	deref: (self: RefData) -> RefData,
	--[=[
		@within RefData
		@tag Method
		@method offset

		Create a reference with specific offset from this reference.
		
		@param offset Create a reference at the given offset
		@return A offseted reference
	]=]
	offset: (self: RefData, offset: number) -> RefData,
	--[=[
		@within RefData
		@tag Method
		@method ref

		Create a reference of this reference.

		The created reference keeps the box from being garbage collected until the reference itself is collected.

		@return A reference of this reference
	]=]
	ref: (self: RefData) -> RefData,
	--[=[
		@within RefData
		@tag Method
		@method leak

		Create a reference of this reference after leaking it.

		GC doesn't manage destruction after this action. You must free it later.

		@return A reference of this reference
	]=]
	leak: (self: RefData) -> RefData,
	--[=[
		@within RefData
		@tag Method
		@method isNull

		Check reference is null or not.

		@return Whether reference is null or not
	]=]
	isNull: (self: RefData) -> boolean,
	--[=[
		@within RefData
		@tag Method
		@method copyFrom

		Copy content from another data.

		@param src The source data
		@param len The amount of data to copy, in bytes
		@param dstOffset The offset in the destination where the data will be pasted
		@param srcOffset The offset in the source data from where the data will be copied
	]=]
	copyFrom: (
		self: RefData,
		src: BoxData | RefData,
		length: number,
		dstOffset: number,
		srcOffset: number
	) -> (),
}

--[=[
	@class BoxData
	
	A user manageable heap memory.
]=]
export type BoxData = {
	--[=[
		@within BoxData
		@tag Field
		@field size

		The size of the box.
	]=]
	size: number,

	--[=[
		@within BoxData
		@tag Method
		@method zero

		Fill the box with zero.

		@return `Box` itself for convenience
	]=]
	zero: (self: BoxData) -> BoxData,
	--[=[
		@within BoxData
		@tag Method
		@method leak

		Create a reference of the box after leaking it.

		GC doesn't manage destruction after this action. You must free it later.

		@param offset Create a reference at the given offset
		@return A reference of the box
	]=]
	leak: (self: BoxData, offset: number?) -> RefData,
	--[=[
		@within BoxData
		@tag Method
		@method ref

		Create a reference of the box.

		The created reference keeps the box from being garbage collected until the reference itself is collected.

		@param offset Create a reference at the given offset
		@return A reference of the box
	]=]
	ref: (self: BoxData, offset: number?) -> RefData,
	--[=[
		@within BoxData
		@tag Method
		@method copyFrom

		Copy content from another data.

		@param src The source data
		@param len The amount of data to copy, in bytes
		@param dstOffset The offset in the destination where the data will be pasted
		@param srcOffset The offset in the source data from where the data will be copied
	]=]
	copyFrom: (
		self: BoxData,
		src: BoxData | RefData,
		length: number,
		dstOffset: number,
		srcOffset: number
	) -> (),
}

--[=[
	@class LibData

	A dynamic opened library handle.
]=]
export type LibData = {
	--[=[
		@within LibData
		@tag Method
		@method find

		Find a symbol from the dynamic library.

		@param sym The name of the symbol
		@return A `Ref` of the found symbol
	]=]
	find: (self: LibData, sym: string) -> RefData,
}

-- export type AppliedCallable = ()->()

--[=[
	@class CallableData
	
	A callable external function.

	To call external function, you should provide memory for the return value and references for the arguments.

	If return type is `void`, pass `nil`.
]=]
export type CallableData = (
	ret: (RefData | BoxData)?,
	...RefData
) -> () & {
	-- apply: (self: Callable, args: Args)->AppliedCallable,
}

--[=[
	@class ClosureData
	
	A lua function wrapper for the function pointer.

	To return some data, write value into ret reference.
]=]
export type ClosureData = {
	--[=[
		@within ClosureData
		@tag Method
		@method ref

		Create a reference of the closure. usually can be used for passing function pointer as argument.

		The created reference keeps the closure from being garbage collected until the reference itself is collected.

		@return A reference of the closure
	]=]
	ref: (self: ClosureData) -> RefData,
}
--#endregion Data

--#region C ABI Type Infos
-- NOTE: T is a unique identifier for the `CType` and R is the closest Lua type.
export type CTypeInfo<T, R> = {
	--[=[
		@within CTypeInfo
		@tag Field
		@field size

		The size of the type in bytes.
	]=]
	size: number,
	--[=[
		@within CTypeInfo
		@tag Field
		@field signedness

		The signedness of the type.
	]=]
	signedness: boolean,

	-- subtype
	--[=[
		@within CTypeInfo
		@tag Method
		@Method ptr

		Create a pointer subtype.

		@return A pointer subtype
	]=]
	ptr: (self: CTypeInfo<T, R>) -> CPtrInfo<CTypeInfo<T, R>>,

	--[=[
		@within CTypeInfo
		@tag Method
		@Method arr

		Create an array subtype.

		@param len The length of the array
		@return An array subtype
	]=]
	arr: (self: CTypeInfo<T, R>, len: number) -> CArrInfo<CTypeInfo<T, R>, R>,

	-- realize
	--[=[
		@within CTypeInfo
		@tag Method
		@Method box

		Create a box with initial values

		@param table The array of field values
		@return A box
	]=]
	box: (self: CTypeInfo<T, R>, val: R) -> BoxData,

	--[=[
		@within CTypeInfo
		@tag Method
		@method readData

		Read a lua table from reference or box.

		@param target Target to read data from
		@param offset Offset to read data from
		@return A table
	]=]
	readData: (self: CTypeInfo<T, R>, target: RefData | BoxData, offset: number?) -> R,

	--[=[
		@within CTypeInfo
		@tag Method
		@method writeData

		Write a lua table into reference or box.

		@param target Target to write data into
		@param table Lua data to write
		@param offset Offset to write data into
	]=]
	writeData: (self: CTypeInfo<T, R>, target: RefData | BoxData, value: R, offset: number?) -> (),
	
	--[=[
		@within CTypeInfo
		@tag Method
		@Method copyData
	
		Copy values ​​from the source and paste them into the target.
	
		@param destination where the data will be pasted
		@param src The source data
		@param dstOffset The offset in the destination where the data will be pasted
		@param srcOffset The offset in the source data from where the data will be copied
	]=]
	copyData: (
		self: CTypeInfo<T, R>,
		dst: RefData | BoxData,
		src: RefData | BoxData,
		dstOffset: number?,
		srcOffset: number?
	) -> (),

	--[=[
		@within CTypeInfo
		@tag Method
		@Method stringifyData
	
		stringify data. Useful when you need to output numbers that Lua can't handle.
	
		@param memory to output
		@param memory byte offset
	]=]
	stringifyData: (self: CTypeInfo<T, R>, target: RefData | BoxData, offset: number?) -> string,

	-- FIXME: recursive types; 'intoType' should be CTypes
	--[=[
		@within CTypeInfo
		@tag Method
		@Method cast
	
		casting a value to a different type.

		may result in loss of precision.

		@param type to convert
		@param memory to read the value to be converted
		@param memory to use the converted value
		@param memory byte offset to read
		@param memory byte offset to write
	]=]
	cast: (
		self: CTypeInfo<T, R>,
		intoType: any,
		fromData: RefData | BoxData,
		intoData: RefData | BoxData,
		fromOffset: number?,
		intoOffset: number?
	) -> (),
} & { ["__phantom"]: T }
type NumCType<T> = CTypeInfo<T, (number | any)>

export type CPtrInfo<T> = {
	--[=[
		@within CPtrInfo
		@tag Field
		@field size

		The size of a pointer. should be the same for all pointers.

		Equivalent to `ffi.c.usize.size`.
	]=]
	size: number,
	--[=[
		@within CPtrInfo
		@tag Field
		@field inner

		The inner type of the pointer.
	]=]
	inner: T,

	-- subtype
	-- FIXME: recursive types; result 'any' should be CArrInfo<CPtrInfo<T>>
	--[=[
		@within CPtrInfo
		@tag Method
		@Method arr

		Create an array subtype.

		@param len The length of the array
		@return An array subtype
	]=]
	arr: (self: CPtrInfo<T>, len: number) -> any,
	
	-- FIXME: recursive types; result 'any' should be CPtrInfo<CPtrInfo<T>>
	--[=[
		@within CPtrInfo
		@tag Method
		@Method ptr

		Create a pointer subtype.

		@return A pointer subtype
	]=]
	ptr: (self: CPtrInfo<T>) -> any,

	--[=[
		@within CPtrInfo
		@tag Method
		@Method readRef
	
		Similar to readData, read a lua value from reference.
	
		@param target Target reference to read data from
		@param offset Offset to read data from
		@return A lua value
	]=]
	readRef: (self: CPtrInfo<T>, target: RefData | BoxData, offset: number?) -> any,

	--[=[
		@within CPtrInfo
		@tag Method
		@Method writeRef

	 	Similar to writeData, write a lua value into reference.
	
		@param target Target reference to write data into
		@param value Lua data to write
		@param offset Offset to write data into
	]=]
	writeRef: (
		self: CPtrInfo<T>,
		target: RefData | BoxData,
		value: RefData | BoxData,
		offset: number?
	) -> (),
}

--[=[
	@class CArrInfo

	A c sized array type information.
]=]
export type CArrInfo<T, R> = {
	--[=[
		@within CArrInfo
		@tag Field
		@field size

		The total size of the array in bytes.
	]=]
	size: number,
	--[=[
		@within CArrInfo
		@tag Field
		@field length

		The length of the array.
	]=]
	length: number,
	--[=[
		@within CArrInfo
		@tag Field
		@field inner

		The inner element type of the array.
	]=]
	inner: T,

	-- subtype
	--[=[
		@within CArrInfo
		@tag Method
		@Method ptr

		Create a pointer subtype.

		@return A pointer subtype
	]=]
	ptr: (self: CArrInfo<T, R>) -> CPtrInfo<CArrInfo<T, R>>,

	-- realize
	--[=[
		@within CArrInfo
		@tag Method
		@Method box

		Create a box with initial values.

		@param table The array of field values
		@return A box
	]=]
	box: (self: CArrInfo<T, R>, table: { T }) -> BoxData,

	--[=[
		@within CArrInfo
		@tag Method
		@method readData

		Read a lua table from reference or box.

		@param target Target to read data from
		@param offset Offset to read data from
		@return A table
	]=]
	readData: (self: CArrInfo<T, R>, target: RefData | BoxData, offset: number?) -> { T },

	--[=[
		@within CArrInfo
		@tag Method
		@method writeData

		Write a lua table into reference or box.

		@param target Target to write data into
		@param table Lua data to write
		@param offset Offset to write data into
	]=]
	writeData: (
		self: CArrInfo<T, R>,
		target: RefData | BoxData,
		value: { R },
		target_offset: number?
	) -> (),

	--[=[
		@within CArrInfo
		@tag Method
		@Method copyData
	
		Copy values ​​from the source and paste them into the target.
	
		@param dst where the data will be pasted
		@param src The source data
		@param dstOffset The offset in the dst where the data will be pasted
		@param srcOffset The offset in the source data from where the data will be copied
	]=]
	copyData: (
		self: CArrInfo<T, R>,
		dst: RefData | BoxData,
		src: RefData | BoxData,
		dstOffset: number?,
		srcOffset: number?
	) -> (),

	--[=[
		@within CArrInfo
		@tag Method
		@method offset

		Get the byte offset of the field.
		
		@param The element index
		@return byte offset
	]=]
	offset: (self: CArrInfo<T, R>, index: number) -> number,
}

--[=[
	@class CFnInfo

	A c function signature type information.
]=]
export type CFnInfo = {
	--[=[
		@within CFnInfo
		@tag Field
		@field size

		The size of a function pointer.

		Equivalent to `ffi.c.usize.size`.
	]=]
	size: number,
	--[=[
		@within CFnInfo
		@tag Method
		@method callable

		Create a callable from reference.

		@return A callable
	]=]
	callable: (self: CFnInfo, functionRef: RefData) -> CallableData,
	--[=[
		@within CFnInfo
		@tag Method
		@method closure

		Create a closure from lua function.

		@return A closure
	]=]
	closure: (self: CFnInfo, (ret: RefData, ...RefData) -> ()) -> ClosureData,
}

--[=[
	@class CStructInfo

	A c struct type information.
]=]
export type CStructInfo = {
	--[=[
		@within CStructInfo
		@tag Field
		@field size

		The size of a struct, including padding.
	]=]
	size: number,

	--[=[
		@within CSturctInfo
		@tag Method
		@method arr

		Create a struct array type.

		@param len The length of the array
		@return A struct array type
	]=]
	arr: (self: CStructInfo, len: number) -> CArrInfo<CStructInfo, { any }>,
	--[=[
		@within CSturctInfo
		@tag Method
		@method ptr

		Create a struct pointer type.

		@return A struct pointer type
	]=]
	ptr: (self: CStructInfo) -> CPtrInfo<CStructInfo>,

	--[=[
		@within CSturctInfo
		@tag Method
		@method box

		Create a box with initial value.

		@param table The array of field values
		@return A box
	]=]
	box: (self: CStructInfo, table: { any }) -> BoxData,
	--[=[
		@within CSturctInfo
		@tag Method
		@method readData

		Read a lua table from reference or box.

		@param target Target to read data from
		@param offset Offset to read data from
		@return A table
	]=]
	readData: (self: CStructInfo, target: RefData | BoxData, offset: number?) -> { any },
	--[=[
		@within CSturctInfo
		@tag Method
		@method writeData

		Write a lua table into reference or box.

		@param target Target to write data into
		@param table Lua data to write
		@param offset Offset to write data into
	]=]
	writeData: (
		self: CStructInfo,
		target: RefData | BoxData,
		table: { any },
		offset: number?
	) -> (),
	--[=[
		@within CSturctInfo
		@tag Method
		@method copyData

		Copy values from the source and paste them into the target.

		@param destination where the data will be pasted
		@param src The source data
		@param dstOffset The offset in the destination where the data will be pasted
		@param srcOffset The offset in the source data from where the data will be copied
	]=]
	copyData: (
		self: CStructInfo,
		dst: RefData | BoxData,
		src: RefData | BoxData,
		dstOffset: number?,
		srcOffset: number?
	) -> (),

	--[=[
		@within CSturctInfo
		@tag Method
		@method copyData

		returns the byte offset of the field.

		@param field index
		@return the byte offset
	]=]
	offset: (self: CStructInfo, index: number) -> number,

	--[=[
		@within CSturctInfo
		@tag Method
		@method field

		Get the field type.
		
		@param index The field index
		@return The field type
	]=]
	field: (self: CStructInfo, index: number) -> CTypes,
}

--[=[
	@class CVoidInfo

	A type that represents c void. can only be used for the function return type.
]=]
export type CVoidInfo = {
	--[=[
		@within CVoidInfo
		@tag Field
		@field size

		The size of the void type. It is always 0.
	]=]
	size: number,
	--[=[
		@within CVoidInfo
		@tag Method
		@method ptr

		Create a generic pointer type.

		@return Generic pointer type, equivalent to `*void` in C.
	]=]
	ptr: (self: CVoidInfo) -> CPtrInfo<CVoidInfo>,
}
c.void = {} :: CVoidInfo
--#endregion C ABI Type Infos

--#region Fixed size Rust-style types
--[=[
	@prop u8 NumCType
	@within FFI

	A 8-bit sized unsigned integer, Equivalent to `uint8_t` in `stdint`.
]=]
ffi.u8 = {} :: u8
export type u8 = NumCType<"u8">
--[=[
	@prop u16 NumCType
	@within FFI

	A 16-bit sized unsigned integer, Equivalent to `uint16_t` in `stdint`.
]=]
ffi.u16 = {} :: u16
export type u16 = NumCType<"u16">
--[=[
	@prop u32 NumCType
	@within FFI

	A 32-bit sized unsigned integer, Equivalent to `uint32_t` in `stdint`.
]=]
ffi.u32 = {} :: u32
export type u32 = NumCType<"u32">
--[=[
	@prop u64 NumCType
	@within FFI

	A 64-bit sized unsigned integer, Equivalent to `uint64_t` in `stdint`.
]=]
ffi.u64 = {} :: u64
export type u64 = NumCType<"u64">
--[=[
	@prop u128 NumCType
	@within FFI

	A 128-bit sized unsigned integer, Equivalent to `uint128_t` in `stdint`.
]=]
ffi.u128 = {} :: u128
export type u128 = NumCType<"u128">
--[=[
	@prop i8 NumCType
	@within FFI

	A 8-bit sized signed integer, Equivalent to `int8_t` in `stdint`.
]=]
ffi.i8 = {} :: i8
export type i8 = NumCType<"i8">
--[=[
	@prop i16 NumCType
	@within FFI

	A 16-bit sized signed integer, Equivalent to `int16_t` in `stdint`.
]=]
ffi.i16 = {} :: i16
export type i16 = NumCType<"i16">
--[=[
	@prop i32 NumCType
	@within FFI

	A 32-bit sized signed integer, Equivalent to `int32_t` in `stdint`.
]=]
ffi.i32 = {} :: i32
export type i32 = NumCType<"i32">
--[=[
	@prop i64 NumCType
	@within FFI

	A 64-bit sized signed integer, Equivalent to `int64_t` in `stdint`.
]=]
ffi.i64 = {} :: i64
export type i64 = NumCType<"i64">
--[=[
	@prop i128 NumCType
	@within FFI

	A 128-bit sized signed integer, Equivalent to `int128_t` in `stdint`.
]=]
ffi.i128 = {} :: i128
export type i128 = NumCType<"i128">
--[=[
	@prop f32 NumCType
	@within FFI

	A single-precision 32-bit sized floating-point, Almost always equivalent to `float` in C.
]=]
ffi.f32 = {} :: f32
export type f32 = NumCType<"f32">
--[=[
	@prop f64 NumCType
	@within FFI

	A double-precision 64-bit sized floating-point, Almost always equivalent to `double` in C.
]=]
ffi.f64 = {} :: f64
export type f64 = NumCType<"f64">
--[=[
	@prop usize NumCType
	@within FFI

	A machine specific pointer sized unsigned integer.
]=]
ffi.usize = {} :: usize
export type usize = NumCType<"usize">
--[=[
	@prop isize NumCType
	@within FFI

	A machine specific pointer sized signed integer.
]=]
ffi.isize = {} :: isize
export type isize = NumCType<"isize">
--#endregion Fixed size Rust-style types

--#region Variable size C-style types
--[=[
	@prop char NumCType
	@within C

	Compiler defined C `char` type.

	The signedness may differ depending on the compiler and platform.

	You can get signedness by `signedness` field.
]=]
c.char = {} :: char
export type char = NumCType<"char">
--[=[
	@prop uchar NumCType
	@within C

	Compiler defined C `unsigned char` type.

	Mostly equivalent to `u8`.
]=]
c.uchar = {} :: uchar
export type uchar = NumCType<"uchar">
--[=[
	@prop schar NumCType
	@within C

	Compiler defined C `signed char` type.
]=]
c.schar = {} :: schar
export type schar = NumCType<"schar">
--[=[
	@prop short NumCType
	@within C

	Compiler defined C `short` type.
]=]
c.short = {} :: short
export type short = NumCType<"short">
--[=[
	@prop ushort NumCType
	@within C

	Compiler defined C `unsigned short` type.
]=]
c.ushort = {} :: ushort
export type ushort = NumCType<"ushort">
--[=[
	@prop int NumCType
	@within C

	Compiler defined C `int` type.

	The side may differ depending on the compiler and platform.
]=]
c.int = {} :: int
export type int = NumCType<"int">
--[=[
	@prop uint NumCType
	@within C

	Compiler defined C `unsigned int` type.

	The side may differ depending on the compiler and platform.
]=]
c.uint = {} :: uint
export type uint = NumCType<"uint">
--[=[
	@prop long NumCType
	@within C

	Compiler defined C `long` type.

	The side may differ depending on the compiler and platform.
]=]
c.long = {} :: long
export type long = NumCType<"long">
--[=[
	@prop ulong NumCType
	@within C

	Compiler defined C `unsigned long` type.

	The side may differ depending on the compiler and platform.
]=]
c.ulong = {} :: ulong
export type ulong = NumCType<"ulong">
--[=[
	@prop longlong NumCType
	@within C

	Compiler defined C `unsigned longlong` type.
]=]
c.longlong = {} :: longlong
export type longlong = NumCType<"longlong">
--[=[
	@prop longlong NumCType
	@within C

	Compiler defined C `unsigned longlong` type.
]=]
c.ulonglong = {} :: ulonglong
export type ulonglong = NumCType<"ulonglong">
--#endregion Variable size C-style types

--[=[
	@class CTypes

	All possible C types.
]=]
export type CTypes =
	u8
	| u16
	| u32
	| u64
	| u128
	| i8
	| i16
	| i32
	| i64
	| i128
	| f32
	| f64
	| usize
	| isize
	| char
	| uchar
	| schar
	| short
	| ushort
	| int
	| uint
	| long
	| ulong
	| longlong
	| ulonglong
	| CArrInfo<CTypes, any>
	| CPtrInfo<CTypes>
	| CFnInfo
	| CStructInfo
	| CVoidInfo

--[=[
	@within C

	Create a function signature type information.

	@param args An array of CTypes represents the arguments of the function
	@param ret The return type of the function
	@return A function signature type information
]=]
function c.fn(args: { CTypes }, ret: CTypes): CFnInfo
	return nil :: any
end

--[=[
	@within C

	Create a struct type information.

	@param fields An array of CTypes represents the fields of the struct
	@return A struct type information
]=]
function c.struct(fields: { CTypes }): CStructInfo
	return nil :: any
end

--[=[
	@within FFI

	Create a `Ref` with address 0.

	Can be used for receive a pointer from external function or pass it as an argument.

	@return A zero initialized Ref
]=]
function ffi.nullRef(): RefData
	return nil :: any
end

--[=[
	@within FFI

	Create a `Box` with specific size.

	@param size The size of the new box
	@return A allocated box
]=]
function ffi.box(size: number): BoxData
	return nil :: any
end

--[=[
	@within FFI

	Open a dynamic library.

	@param name The name of the target library
	@return A dynamic library handle
]=]
function ffi.open(name: string): LibData
	return nil :: any
end

--[=[
	@within FFI

	Return `true` if the second argument is an integer (i32).

	@param val A lua value to check
	@return Whether val is an integer or not
]=]
function ffi.isInteger<T>(val: T): boolean
	return nil :: any
end

return ffi
