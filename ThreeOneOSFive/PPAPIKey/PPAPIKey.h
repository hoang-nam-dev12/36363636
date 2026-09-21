// PPAPIKey.h
// Created by Phat Pham on 2026/05/07.
// Copyright © 2026 Phat Pham. All rights reserved.

#ifndef PPAPIKEY_H
#define PPAPIKEY_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPAPIKey : NSObject

+ (instancetype)shared;
- (void)setToken:(NSString *)token;
- (void)setEN:(BOOL)enable;
- (void)loading:(void (^)(void))execute;
- (void)setVer:(NSString *)ver;

- (void)packageData:(void (^)(id data))completion;
- (NSString *)getDeviceKey;
- (NSString *)getKeyExpire;
- (NSString *)getKeyAmount;
- (NSString *)getDeviceID;
- (NSString *)getAppBundle;
- (void)exitKey:(void (^)(BOOL success))completion;
- (void)copyKey:(void (^)(BOOL success))completion;

@end

#ifdef __cplusplus
extern "C" {
#endif

void setTokenC(const char *_Nullable token);
void setENC(int enable); // 1 = English, 0 = Vietnamese
void setVerC(const char *_Nullable ver);
void loadingC(void (^_Nonnull execute)(void));
void packageData(void (^_Nonnull completion)(id _Nullable data));
const char *getDeviceKeyC(void);
const char *getKeyExpireC(void);
const char *getKeyAmountC(void);
const char *getDeviceIDC(void);
const char *getAppBundleC(void);
void exitKeyC(void (^_Nonnull completion)(BOOL success));
void copyKeyC(void (^_Nonnull completion)(BOOL success));

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

#endif /* PPAPIKEY_H */
