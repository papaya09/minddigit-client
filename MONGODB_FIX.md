# 🔧 แก้ไข MongoDB Atlas สำหรับ Vercel

## 1. เพิ่ม IP Whitelist บน MongoDB Atlas

1. **เข้าไปที่ MongoDB Atlas Console**
   - ไปที่ [cloud.mongodb.com](https://cloud.mongodb.com)
   - เลือก cluster ของคุณ

2. **เข้าไปที่ Network Access**
   - คลิก "Network Access" ในเมนูซ้าย
   - คลิก "+ ADD IP ADDRESS"

3. **เพิ่ม IP Address สำหรับ Vercel**
   - เลือก "Add a different IP address"
   - ใส่ `0.0.0.0/0` (อนุญาตทุก IP - สำหรับ Vercel)
   - หรือใส่ Vercel IP ranges: `76.76.19.0/24` และ `76.223.126.0/24`
   - Comment: "Vercel deployment"
   - คลิก "Confirm"

## 2. ตั้งค่า Environment Variables บน Vercel

1. **เข้าไปที่ Vercel Dashboard**
   - ไปที่ [vercel.com/dashboard](https://vercel.com/dashboard)
   - เลือกโปรเจกต์ `minddigit-server`

2. **ไปที่ Settings → Environment Variables**
   - คลิก "Settings" tab
   - คลิก "Environment Variables"

3. **เพิ่ม Environment Variables**
   ```
   Name: MONGODB_URI
   Value: mongodb+srv://username:password@cluster.mongodb.net/minddigits
   
   Name: CORS_ORIGIN  
   Value: *
   
   Name: PORT
   Value: 3000
   ```

4. **Redeploy โปรเจกต์**
   - ไปที่ "Deployments" tab
   - คลิก "..." บน deployment ล่าสุด
   - เลือก "Redeploy"

## 3. ตรวจสอบการเชื่อมต่อ

หลังจากแก้ไขแล้ว ลองเข้าไปที่:
- `https://minddigit-server.vercel.app/` - ควรเห็น status: running
- ตรวจสอบ logs บน Vercel ว่าไม่มี MongoDB connection error

## 4. ทดสอบใน iOS App

1. เปิด iOS app 
2. ลอง "CREATE ROOM" 
3. ลอง "JOIN ROOM" กับรหัสที่สร้าง
4. ควรเห็น room list และเข้าเกมได้

## 📝 หมายเหตุ

- `0.0.0.0/0` หมายถึงอนุญาตทุก IP (ใช้สำหรับ development)
- สำหรับ production ควรใช้ IP ranges ที่เฉพาะเจาะจงมากขึ้น
- ตรวจสอบ MongoDB connection string ให้ถูกต้อง 