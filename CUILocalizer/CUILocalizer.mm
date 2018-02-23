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
                newText = forceChangePartInString(@" of ", newText, @"of");
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
    
    //  Только асинхронно и в авторелизном пуле, ибо проблемы с памятью и падение производительности при запуске нам не нужны
    @autoreleasepool {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            theuxAdBlockAvailable = [[NSFileManager defaultManager] fileExistsAtPath:[[NSBundle mainBundle] pathForResource:@"theuxUAAdRem" ofType:@"dylib"]];
            is_iapps = (NSClassFromString(@"Activation") != nil);
            
            NSError *error = nil;
            NSURL *provisionURL = [[NSBundle mainBundle] URLForResource:@"embedded" withExtension:@"mobileprovision"];
            NSString *provisionString = [[NSString alloc] initWithContentsOfURL:provisionURL encoding:NSISOLatin1StringEncoding error:&error];
            
            //  embedded.mobileprovision присутствует только в самоподписанном приложении
            //  поэтому проверяем на отсутствие ошибки
            if (!error) {
                NSString *provisionDictString = @"";
                
                NSScanner *scanner = [NSScanner scannerWithString:provisionString];
                [scanner scanUpToString:@"<plist" intoString:nil];
                [scanner scanUpToString:@"</plist>" intoString:&provisionDictString];
                provisionDictString = [@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" 
                                       stringByAppendingString:provisionDictString];
                provisionDictString = [provisionDictString stringByAppendingString:@"</plist>"];
                
                //  Для предотвращения ошибок в колореде пишем в файл с другим именем
                NSString *tempPath = [NSTemporaryDirectory() stringByAppendingString:@"/embedded_mobileprovision1.plist"];
                [[provisionDictString dataUsingEncoding:NSUTF8StringEncoding] writeToFile:tempPath atomically:YES];
                
                NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:tempPath];
                if (dict) {
                    NSArray <NSString *> *certificatesToBlock = @[@"FL663S8EYD", // Vektum Tsentr, OOO]
                                                                  @"9DT3883ETD" //  Meridian Medical Network Corp.
                                                                  ];
                    NSString *appTeamIdentifier = ((NSArray *)dict[@"TeamIdentifier"]).firstObject;
                    is_theux = ![certificatesToBlock containsObject:appTeamIdentifier];
                }
                [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
            }
        });
    }
    
}
