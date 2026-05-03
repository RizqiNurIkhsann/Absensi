<!DOCTYPE html>
<html>
<head>
    <title>Kode OTP Reset Password</title>
</head>
<body style="font-family: Arial, sans-serif; background-color: #f4f7f6; margin: 0; padding: 20px;">
    <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <div style="background-color: #0f172a; padding: 20px; text-align: center;">
            <h2 style="color: #eab308; margin: 0;">Reset Password</h2>
        </div>
        <div style="padding: 30px; color: #333;">
            <p>Halo,</p>
            <p>Seseorang telah meminta perubahan kata sandi untuk akun Anda di sistem kami.</p>
            <p>Berikut adalah kode OTP untuk memverifikasi perubahan kata sandi Anda:</p>
            
            <div style="text-align: center; margin: 30px 0;">
                <span style="font-size: 32px; font-weight: bold; background-color: #f8fafc; padding: 15px 30px; border-radius: 8px; border: 1px dashed #cbd5e1; letter-spacing: 5px;">{{ $otp }}</span>
            </div>
            
            <p style="color: #ef4444; font-size: 14px; font-weight: bold;">Kode ini akan kedaluwarsa dalam 15 menit.</p>
            <p>Jika Anda tidak merasa meminta reset password, silakan abaikan email ini.</p>
            <br>
            <p>Terima kasih,<br><strong>Tim IT Support</strong></p>
        </div>
        <div style="background-color: #f8fafc; text-align: center; padding: 15px; font-size: 12px; color: #64748b;">
            &copy; {{ date('Y') }} PT. United Tractors. All rights reserved.
        </div>
    </div>
</body>
</html>
