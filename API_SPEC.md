# API Specification for Continue Guessing Mode

## New API Endpoint: `/game/opponent-secret`

### Purpose
Fetch the opponent's secret for continue guessing mode when a player loses.

### Request
```http
POST /game/opponent-secret
Content-Type: application/json

{
  "roomId": "string",
  "playerId": "string"
}
```

### Response
```json
{
  "success": true,
  "opponentSecret": "1234",
  "opponentPlayerId": "player456",
  "opponentPlayerName": "Player 2"
}
```

### Error Response
```json
{
  "success": false,
  "error": "Room not found / Player not found / Game not finished"
}
```

### Logic Requirements
1. **Verify game is finished** - Only allow when gameState = "FINISHED"
2. **Verify requester is loser** - Only the losing player can request opponent secret
3. **Find opponent** - Get the other player's data from the room
4. **Return opponent's secret** - Send back the winner's secret for analysis

### Server Implementation Example (Node.js/Express)
```javascript
app.post('/api/game/opponent-secret', async (req, res) => {
  try {
    const { roomId, playerId } = req.body;
    
    // Find room
    const room = await Room.findById(roomId);
    if (!room) {
      return res.json({ success: false, error: "Room not found" });
    }
    
    // Verify game is finished
    if (room.gameState !== "FINISHED") {
      return res.json({ success: false, error: "Game not finished yet" });
    }
    
    // Find requester and opponent
    const requester = room.players.find(p => p.id === playerId);
    const opponent = room.players.find(p => p.id !== playerId);
    
    if (!requester || !opponent) {
      return res.json({ success: false, error: "Player not found" });
    }
    
    // Verify requester is not the winner
    if (room.winner.playerId === playerId) {
      return res.json({ success: false, error: "Winner cannot request opponent secret" });
    }
    
    // Return opponent's secret
    res.json({
      success: true,
      opponentSecret: opponent.secret,
      opponentPlayerId: opponent.id,
      opponentPlayerName: opponent.playerName
    });
    
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});
```

### Security Considerations
- Only losing player can access opponent's secret
- Only after game is officially finished
- Rate limiting to prevent abuse
- Validate room and player existence

### Client Usage
Called automatically when:
1. Player clicks "Continue Assault" button
2. opponentSecret is empty during analysis
3. Need to refresh opponent secret data