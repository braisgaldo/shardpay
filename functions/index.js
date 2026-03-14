const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');

admin.initializeApp();
setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

exports.pushUserNotification = onDocumentCreated('users/{userId}/notifications/{notificationId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }

  const notification = snapshot.data();
  const userId = event.params.userId;
  const userSnapshot = await admin.firestore().collection('users').doc(userId).get();
  const userData = userSnapshot.data() || {};
  const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens.filter((token) => typeof token === 'string' && token.length > 0) : [];

  if (tokens.length === 0) {
    logger.info('No FCM tokens registered for user', { userId, notificationId: snapshot.id });
    return;
  }

  const amount = notification.amount == null ? '' : String(notification.amount);
  const payload = {
    tokens,
    notification: {
      title: notification.title || 'ShardPay',
      body: notification.message || '',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'shardpay_messages',
        priority: 'high',
        defaultSound: true,
        tag: snapshot.id,
      },
    },
    data: {
      id: snapshot.id,
      type: notification.type || 'expenseAdded',
      title: notification.title || 'ShardPay',
      message: notification.message || '',
      groupId: notification.groupId || '',
      expenseId: notification.expenseId || '',
      fromUserId: notification.fromUserId || '',
      relatedUserId: notification.relatedUserId || '',
      amount,
    },
  };

  const response = await admin.messaging().sendEachForMulticast(payload);
  const invalidTokens = [];

  response.responses.forEach((result, index) => {
    if (result.success) {
      return;
    }
    const code = result.error && result.error.code;
    if (code === 'messaging/invalid-registration-token' || code === 'messaging/registration-token-not-registered') {
      invalidTokens.push(tokens[index]);
    } else {
      logger.error('FCM send failed', {
        userId,
        notificationId: snapshot.id,
        token: tokens[index],
        error: result.error,
      });
    }
  });

  if (invalidTokens.length > 0) {
    await admin.firestore().collection('users').doc(userId).set({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      updatedAt: new Date().toISOString(),
    }, { merge: true });
  }
});