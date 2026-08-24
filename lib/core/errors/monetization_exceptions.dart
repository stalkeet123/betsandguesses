const freeHostLimitReachedMessage = 'FREE_HOST_LIMIT_REACHED';

bool isFreeHostLimitReachedMessage(String message) =>
    message == freeHostLimitReachedMessage;

class FreeHostLimitReachedException implements Exception {
  const FreeHostLimitReachedException();
}
