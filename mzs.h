#ifndef MZS_H
#define MZS_H

#define MZS_UCOM_PLAY_SONG(song)              MZS_send_user_command(0x01, song)
#define MZS_UCOM_STOP()                       MZS_send_user_command(0x02, 0)
#define MZS_UCOM_BUFFER_SFXPS_CVOL(pan, cvol) MZS_send_user_command(0x03, (pan) | ((cvol) & 0x1F))
#define MZS_UCOM_BUFFER_SFXPS_PRIO(prio)      MZS_send_user_command(0x04, prio)
#define MZS_UCOM_PLAY_SFXPS_SMP(smp)          MZS_send_user_command(0x05, smp)
#define MZS_UCOM_SET_MLM_MVOL(mvol)           MZS_send_user_command(0x06 | (mvol & 1), mvol >> 1)
#define MZS_UCOM_SET_FADE(ofs)                MZS_send_user_command((0x08 | ((ofs >> 7) & 1)), ofs & 0x7F)
#define MZS_UCOM_RETRIG_SFXPS_SMP(smp)        MZS_send_user_command(0x0B, smp)

typedef enum {
    PAN_NONE   = 0x00,
    PAN_LEFT   = 0x40,
    PAN_RIGHT  = 0x20,
    PAN_CENTER = 0x60,
} MZS_Panning;

void MZS_send_user_command(unsigned char command, unsigned char parameter);

inline void MZS_UCOM_play_song(unsigned char song)
{ MZS_send_user_command(0x01, song); }

inline void MZS_UCOM_stop_song()
{ MZS_send_user_command(0x02, 0); }

inline void MZS_UCOM_buffer_sfxps_cvol(MZS_Panning pan, unsigned char cvol)
{ MZS_send_user_command(0x03, (pan) | ((cvol) & 0x1F)); }

inline void MZS_UCOM_buffer_sfxps_prio(unsigned char prio)
{ MZS_send_user_command(0x04, prio); }

inline void MZS_UCOM_play_sfxps_smp(unsigned char smp)
{ MZS_send_user_command(0x05, smp); }

inline void MZS_UCOM_set_mlm_vol(unsigned char mvol)
{ MZS_send_user_command(0x06 | (mvol & 1), mvol >> 1); }

inline void MZS_UCOM_set_fade(signed char fade)
{ MZS_send_user_command(0x08 | *((unsigned char*)(&fade)) >> 7, *((unsigned char*)(&fade)) & 0x7F); }

#ifdef MZS_IMPLEMENTATION
void __attribute__((optimize("O0"))) __MZS_wait_loop(int loops)
{
    for(unsigned short i = 0; i < loops; ++i);
}

void MZS_send_user_command(unsigned char command, unsigned char parameter)
{
    const unsigned char user_com_mask = 0x80;
    command |= user_com_mask;
    parameter |= user_com_mask;

    *((volatile unsigned char*)0x320000) = command;
    unsigned char neg_command = command ^ 0xFF;
    while (*((volatile unsigned char*)0x320000) != neg_command);
    __MZS_wait_loop(64);

    *((volatile unsigned char*)0x320000) = parameter;
    unsigned char neg_parameter = parameter ^ 0xFF;
    while (*((volatile unsigned char*)0x320000) != neg_parameter);
    __MZS_wait_loop(64);
}
#endif

#endif