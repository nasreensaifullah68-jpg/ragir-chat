const admin = require('firebase-admin');

function init() {
  if (!admin.apps.length) {
    const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({ credential: admin.credential.cert(sa) });
  }
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'use POST' });
  }
  try {
    init();
    const idToken = (req.headers.authorization || '').replace('Bearer ', '');
    const me = await admin.auth().verifyIdToken(idToken);
    const b = req.body || {};
    const toUid = String(b.toUid || '');
    if (!toUid || toUid === me.uid) {
      return res.status(400).json({ ok: false, error: 'bad toUid' });
    }
    const db = admin.firestore();
    const chatId = [me.uid, toUid].sort().join('_');
    const chat = await db.collection('chats').doc(chatId).get();
    if (!chat.exists) {
      return res.status(403).json({ ok: false, error: 'no chat' });
    }
    const user = await db.collection('users').doc(toUid).get();
    const token = user.exists ? user.data().fcm : null;
    if (!token) {
      return res.status(200).json({ ok: false, reason: 'no-token' });
    }
    const isCall = b.kind === 'call';
    await admin.messaging().send({
      token,
      notification: {
        title: String(b.title || 'Rahgeer Chat').slice(0, 80),
        body: String(b.body || '').slice(0, 200),
      },
      data: { kind: String(b.kind || 'msg'), fromUid: me.uid },
      android: {
        priority: 'high',
        ttl: isCall ? 45000 : 86400000,
        notification: {
          channelId: isCall ? 'calls' : 'messages',
          sound: 'default',
        },
      },
    });
    return res.status(200).json({ ok: true });
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e.message || e) });
  }
};
