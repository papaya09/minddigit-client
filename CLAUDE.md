# 🎯 MindDigits - iOS Number Guessing Game

## 🎮 Project Overview

**MindDigits** เป็นเกมทายเลขแบบผู้เล่นหลายคนที่เล่นผ่าน iOS และ Real-time Server ผู้เล่นจะแข่งขันกันเพื่อทายเลขลับของคู่แข่ง โดยใช้ระบบ "Hit & Blow" แบบดั้งเดิมแต่ปรับให้ทันสมัย

## 🎲 Game Rules & Mechanics

### Core Gameplay
- **ผู้เล่น**: 2-4 คนต่อห้อง
- **โหมดเกม**: 
  - 🔢 1 หลัก (0-9)
  - 🔢 2 หลัก (10-99) 
  - 🔢 3 หลัก (100-999)
  - 🔢 4 หลัก (1000-9999)
- **วิธีการเล่น**: แต่ละคนคิดเลขลับ → ทายเลขของคู่แข่งสลับกัน → ใครทายถูกก่อนชนะ

### Turn System
1. **Setup Phase**: ผู้เล่นทุกคนตั้งเลขลับของตัวเอง
2. **Guessing Phase**: ผู้เล่นทายสลับกันตามลำดับ (Round Robin)
3. **Feedback**: ระบบจะบอกจำนวนเลขที่ถูก (Hit) แต่ไม่บอกตำแหน่ง
4. **Victory**: ผู้เล่นคนแรกที่ทายถูกทั้งหมดจะชนะ

### Example Gameplay
- ผู้เล่น A: เลขลับ `1234`
- ผู้เล่น B: เลขลับ `5678`  
- ผู้เล่น A ทาย `5679` → ได้ผลลัพธ์ "3 หลักถูก" (5,6,7)
- ผู้เล่น B ทาย `1235` → ได้ผลลัพธ์ "3 หลักถูก" (1,2,3)

## 📱 iOS Client Architecture

### 🏗️ App Structure
```
NumberGame/
├── Views/
│   ├── MainMenuView.swift       # หน้าหลัก + เลือกโหมด
│   ├── LobbyView.swift         # รอผู้เล่น + แชท
│   ├── GameView.swift          # หน้าเล่นเกมหลัก
│   ├── ResultView.swift        # แสดงผลลัพธ์ + สถิติ
│   └── SettingsView.swift      # ตั้งค่า + โปรไฟล์
├── Models/
│   ├── GameSession.swift       # จัดการสถานะเกม
│   ├── Player.swift           # ข้อมูลผู้เล่น
│   └── GameHistory.swift      # ประวัติการเดา
├── Managers/
│   ├── NetworkManager.swift    # เชื่อมต่อ server
│   ├── GameStateManager.swift  # จัดการสถานะ
│   └── SoundManager.swift     # เสียงและเอฟเฟกต์
└── Utils/
    ├── GameLogic.swift        # คำนวณ Hit/Blow
    └── ValidationUtils.swift   # ตรวจสอบข้อมูล
```

### 🎨 UI/UX Design Concepts

#### Main Menu Screen
```
┌─────────────────────────────────┐
│  🎯 MindDigits                  │
│                                 │
│  👤 [Player Name Input]         │
│                                 │
│  🎮 GAME MODES                  │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐│
│  │ 1D  │ │ 2D  │ │ 3D  │ │ 4D  ││
│  │ 🔥  │ │ ⭐  │ │ 💎  │ │ 👑  ││
│  └─────┘ └─────┘ └─────┘ └─────┘│
│                                 │
│  🏠 [CREATE ROOM]               │
│  🔗 [JOIN ROOM]                 │
│  📊 [STATISTICS]                │
│  ⚙️  [SETTINGS]                 │
└─────────────────────────────────┘
```

#### Game Screen Layout
```
┌─────────────────────────────────┐
│ Room: ABC123    Turn: Player A  │
│ Mode: 4D        Time: 2:30      │
├─────────────────────────────────┤
│ 👥 PLAYERS                      │
│ ✅ You (1234) 🎯               │
│ ⏳ PlayerB    🔥               │  
│ ✅ PlayerC    ⭐               │
├─────────────────────────────────┤
│ 🎯 MAKE YOUR GUESS              │
│                                 │
│    [1][2][3][4]                 │
│                                 │
│ ┌─────┐ ┌─────┐ ┌─────┐         │
│ │  7  │ │  8  │ │  9  │         │
│ ├─────┤ ├─────┤ ├─────┤         │
│ │  4  │ │  5  │ │  6  │         │
│ ├─────┤ ├─────┤ ├─────┤         │
│ │  1  │ │  2  │ │  3  │         │
│ ├─────┼─────────────────┤         │
│ │  0  │      CLEAR      │         │
│ └─────┴─────────────────┘         │
│                                 │
│ [🎯 GUESS PlayerB]              │
├─────────────────────────────────┤
│ 📋 GAME HISTORY                 │
│ You → PlayerB: 5678 = 2 hits    │
│ PlayerB → You: 1235 = 3 hits    │
│ You → PlayerC: 9999 = 0 hits    │
└─────────────────────────────────┘
```

## 🔧 Technical Implementation Plan

### Phase 1: Core Foundation (Week 1-2)
- [x] Setup Xcode project structure
- [x] Implement basic SocketIO connection
- [x] Create fundamental models (Player, Game, Move)
- [x] Setup MongoDB backend
- [ ] **Fix UI bugs and improve visual design**
- [ ] **Implement proper game state management**

### Phase 2: Enhanced UI/UX (Week 2-3) 
- [ ] **Design modern, intuitive interface**
- [ ] **Add smooth animations and transitions** 
- [ ] **Implement haptic feedback**
- [ ] **Create responsive number pad**
- [ ] **Add visual feedback for game states**

### Phase 3: Game Logic (Week 3-4)
- [ ] **Implement turn-based system**
- [ ] **Add multiple game modes (1D, 2D, 3D, 4D)**
- [ ] **Create intelligent guess validation**
- [ ] **Add game timer and timeout handling**
- [ ] **Implement scoring system**

### Phase 4: Multiplayer Features (Week 4-5)
- [ ] **Room management system**
- [ ] **Player matching and lobbies**
- [ ] **Real-time chat during games**
- [ ] **Spectator mode**
- [ ] **Reconnection handling**

### Phase 5: Polish & Advanced Features (Week 5-6)
- [ ] **Sound effects and music**
- [ ] **Achievement system**
- [ ] **Statistics and leaderboards**
- [ ] **Custom themes and avatars**
- [ ] **Tutorial and onboarding**

## 🎯 Current Issues to Fix

### UI/UX Improvements Needed
1. **Visual Polish**
   - Gradient backgrounds instead of solid colors
   - Modern card-based layouts
   - Consistent spacing and typography
   - Better color scheme with accessibility

2. **Interactive Elements**
   - Improved button press feedback
   - Loading states and progress indicators  
   - Error message styling
   - Success/failure animations

3. **Game Flow**
   - Clear turn indicators
   - Better player status display
   - Intuitive guess input system
   - Real-time game state updates

### Technical Improvements
1. **State Management**
   - Implement proper MVVM architecture
   - Add Combine for reactive programming
   - Better error handling
   - Offline mode support

2. **Performance**
   - Optimize SpriteKit rendering
   - Reduce memory usage
   - Smooth 60fps animations
   - Efficient network calls

## 🚀 Development Guidelines

### Code Style
- Use SwiftUI for modern UI components
- Implement MVVM architecture pattern
- Follow iOS Human Interface Guidelines
- Write unit tests for game logic

### Git Workflow
```bash
# Feature development
git checkout -b feature/improved-ui
git commit -m "✨ Add modern game interface"
git push origin feature/improved-ui

# Testing
npm run test        # Backend tests
xcodebuild test     # iOS tests
```

### Build Commands
```bash
# iOS Development
open NumberGame.xcodeproj
# Build for simulator: Cmd+R

# Backend Server
cd server-node
npm run dev         # Development server
npm run build       # Production build
```

## 📋 Success Metrics

### User Experience
- **Intuitive UI**: New users can play within 30 seconds
- **Smooth Performance**: Maintain 60fps during gameplay  
- **Engaging Visuals**: Modern design with delightful animations
- **Accessibility**: Support for VoiceOver and larger text

### Technical Quality  
- **Reliability**: 99.9% uptime for multiplayer sessions
- **Responsiveness**: <100ms response time for game actions
- **Scalability**: Support 100+ concurrent rooms
- **Code Quality**: 90%+ test coverage

## 🌐 Deployment & Server Configuration

### Vercel Deployment Setup
1. **Server บน Vercel**: https://numbergame-server.vercel.app
2. **Environment Variables ที่ต้องตั้งใน Vercel**:
   - `MONGODB_URI`: Connection string ไปยัง MongoDB Atlas
   - `NODE_ENV`: production

### Client Configuration
- **iOS Client**: เชื่อมต่อผ่าน `GameClient.swift:53`
- **Base URL**: `https://numbergame-server.vercel.app`
- **API Endpoints**:
  - `/api/health` - Health check
  - `/api/rooms` - Room management
  - `/api/rooms/join` - Join room
  - `/api/rooms/{code}/state` - Get room state
  - `/api/rooms/secret` - Set secret number
  - `/api/rooms/guess` - Make guess
  - `/api/players/heartbeat` - Keep connection alive

### Common Connection Issues & Solutions

#### ❌ Problem: Client can't connect to server
**Solution**: 
1. ตรวจสอบ URL ใน `GameClient.swift` ว่าตรงกับ Vercel deployment
2. ใน Vercel Dashboard ตั้ง Environment Variable: `MONGODB_URI`
3. Deploy ใหม่หลังจากเปลี่ยน environment variables

#### ❌ Problem: CORS errors in web browser
**Solution**: เพิ่ม CORS middleware ใน server
```javascript
app.use(cors({
  origin: ["https://your-client-domain.com"],
  credentials: true
}));
```

#### ❌ Problem: MongoDB connection timeout
**Solution**: 
1. ตรวจสอบ MongoDB Atlas IP whitelist (เพิ่ม 0.0.0.0/0 สำหรับ Vercel)
2. ตรวจสอบ connection string format: `mongodb+srv://...`

#### ❌ Problem: "option buffermaxentries is not supported"
**Solution**: 
1. ใช้ connection string แบบใหม่ที่ไม่มี deprecated options:
```
mongodb+srv://username:password@cluster.mongodb.net/database?retryWrites=true&w=majority
```
2. อย่าใส่ options เก่าอย่าง `&bufferMaxEntries=0` ใน connection string
3. ใช้ options ใน code แทน connection string

#### ❌ Problem: HTTP 500 errors during polling
**Solution**:
1. เพิ่ม polling interval เพื่อลดภาระ server:
   - Default: 5 วินาที (แทน 2 วินาที)
   - Active game: 3 วินาที
   - Waiting: 5 วินาที  
   - Finished: 10 วินาที
2. ตรวจสอบ MongoDB connection limit ใน Atlas
3. ใช้ HTTP caching headers เพื่อลด database queries

#### ❌ Problem: Polling loop prevents navigation to next screen
**Solution**:
1. ✅ เริ่ม polling หลัง create/join room เพื่อ trigger `didReceiveRoomState` callback
2. ✅ ใช้ `isCreatingRoom` flag สำหรับ create room navigation
3. ✅ ตรวจสอบ `currentRoomCode` ตรงกับ `state.game.code` สำหรับ join room
4. ✅ หยุด polling ก่อน navigate เพื่อป้องกัน loop
5. ✅ Navigation ทำงานผ่าน delegate callback เท่านั้น

#### ✅ Problem: Fixed - Both create and join room now work properly
**Current Status**:
- Create room: ✅ Working (uses isCreatingRoom flag)
- Join room (direct code): ✅ Working  
- Join room (from list): ✅ Working
- Navigation: ✅ Automatic via didReceiveRoomState callback
- Polling: ✅ Stops after navigation to prevent interference

### Auto-deployment from GitHub
1. เชื่อม GitHub repository กับ Vercel
2. ทุกครั้งที่ push ไป `main` branch จะ deploy อัตโนมัติ
3. Environment variables จะถูกใช้โดยอัตโนมัติ

### Testing Connection
```bash
# Test server health
curl https://numbergame-server.vercel.app/api/health

# Expected response:
{"status": "OK", "message": "NumberGame server is running"}
```

---

**Next Steps**: Focus on fixing current UI bugs and implementing the enhanced visual design outlined above. Priority should be on creating a polished, modern gaming experience that users will enjoy.