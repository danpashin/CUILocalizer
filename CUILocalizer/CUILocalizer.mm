//
//  CUILocalizer.mm
//  CUILocalizer
//
//  Created by Даниил on 16.11.17.
//  Copyright (c) 2017 Daniil Pashin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "SCParser.h"

BOOL theuxAdBlockAvailable = NO;
BOOL is_theux = NO;
BOOL is_iapps = NO;

__strong NSDictionary *origLocalizable;

NSString *localizedString(NSString *key);
NSString *forceChangePartInString(NSString *string, NSString *stringToChange, NSString *localizableKey);

@implementation UILabel (CUILocalizer)

+ (void)load
{
    [super load];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method originalMethod = class_getInstanceMethod(self, @selector(setText:));
        Method swizzledMethod = class_getInstanceMethod(self, @selector(cui_setText:));
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

- (void)cui_setText:(NSString *)text
{
    if ((is_theux && theuxAdBlockAvailable) || is_iapps) {
        if (![origLocalizable.allValues containsObject:text]) {
            NSString *newText = localizedString(text);
            
                // Принудительно проверяем на наличие определенных слов в строке
            if ([text isEqual:newText]) {
                newText = forceChangePartInString(@"DOES NOT FOLLOW YOU", newText, nil);
                newText = forceChangePartInString(@"FOLLOWS YOU", newText, nil);
                newText = forceChangePartInString(@"(Selected)", newText, nil);
//                newText = forceChangePartInString(@" of ", newText, @"of");
            }
            text = newText;
        }
    }
    
    [self cui_setText:text];
}

@end



NSString *localizedString(NSString *key)
{
    return NSLocalizedStringFromTable(key, @"CUILocalizable", nil);
}

NSString *forceChangePartInString(NSString *string, NSString *stringToChange, NSString *localizableKey)
{
    if ([stringToChange containsString:string]) {
        if (!localizableKey)
            localizableKey = string;
        
        return [stringToChange stringByReplacingOccurrencesOfString:string withString:localizedString(localizableKey)];
    }
    return stringToChange;
}

static void __attribute__((constructor)) init_dylib(void)
{
    origLocalizable = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings"]];
    if (!origLocalizable) {
        origLocalizable = [NSDictionary dictionary];
    }
    
    theuxAdBlockAvailable = [[NSFileManager defaultManager] fileExistsAtPath:[[NSBundle mainBundle] pathForResource:@"theuxUAAdRem" ofType:@"dylib"]];
    is_iapps = (NSClassFromString(@"Activation") != nil);
    
    SCParser *parser = [SCParser new];
    [parser parseAppProvisionWithCompletion:^(NSDictionary * _Nullable provisionDict, NSError * _Nullable error) {
        if (error)
            return;
        
        NSArray <NSString *> *certificatesToBlock = @[@"FL663S8EYD", // Vektum Tsentr, OOO]
                                                      @"9DT3883ETD" //  Meridian Medical Network Corp.
                                                      ];
        NSString *appTeamIdentifier = ((NSArray *)provisionDict[@"TeamIdentifier"]).firstObject;
        is_theux = ![certificatesToBlock containsObject:appTeamIdentifier];
    }];
    
}
