#ifndef NEOGEO_MESS_H_INCLUDED
#define NEOGEO_MESS_H_INCLUDED

typedef enum MESS_Status {
	MESS_STATUS_OK,
	MESS_STATUS_BUFFER_OVERFLOW,
} MESS_Status;

typedef enum MESS_CharSize {
	MESS_CHARSIZE_BYTE,
	MESS_CHARSIZE_WORD
} MESS_CharSize;

typedef enum MESS_StringType {
	MESS_STRING_TYPE_BYTE_DETERMINATED,
	MESS_STRING_TYPE_LENGTH_PREFIXED,
} MESS_StringType;

// Should be called at the start of 
// each frame (or at least, before
// using any other MESS OUT functions)
MESS_Status MESS_BufferInit();
MESS_Status MESS_EndOfCommandList();
MESS_Status MESS_SetDataFormat(MESS_CharSize char_size, MESS_StringType string_type, u16 delimiter);
MESS_Status MESS_SetAutoIncrement(u8 autoincrement);
MESS_Status MESS_SetVRAMAddress(u16 address);
MESS_Status MESS_SetDataAddress(void* data);
MESS_Status MESS_AddToVRAMAddress(u16 addend);
MESS_Status MESS_ResumeDataOutput();
MESS_Status MESS_DirectDataWrite(char* data, size_t data_size);
MESS_Status MESS_8x16Write(u8 fontset);

#endif