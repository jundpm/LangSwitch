# LangSwitch

macOS용 플로팅 입력 소스 전환기. Chrome Remote Desktop 등 키보드 단축키가 먹히지 않는 환경에서 클릭 한 번으로 한국어/拼音/ABC 등을 전환할 수 있다.

## 기능

- 현재 활성화된 입력 소스를 파란색으로 표시
- 클릭으로 즉시 언어 전환
- 부분 화면 캡처 버튼 (클립보드에 복사)
- 항상 최상단 표시 (Stay on Top)
- 드래그로 위치 이동
- Dock 아이콘 없음
- 모든 데스크톱 Space에서 표시
- 이벤트 기반 동작 (폴링 없음, CPU 사용 거의 0)

## 빌드

Xcode Command Line Tools가 필요하다.

```bash
swiftc -framework Cocoa -framework Carbon -o LangSwitch main.swift
```

## 실행

```bash
./LangSwitch &
```

## 종료

바를 우클릭 → 종료

## 로그인 시 자동 실행

`~/Library/LaunchAgents/com.seongjunk.langswitch.plist`를 만들고:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.seongjunk.langswitch</string>
    <key>ProgramArguments</key>
    <array>
        <string>/절대경로/LangSwitch</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

등록:

```bash
launchctl load ~/Library/LaunchAgents/com.seongjunk.langswitch.plist
```

## alias 등록

`~/.zshrc`에 추가:

```bash
alias langswitch="/절대경로/LangSwitch &"
```

이후 터미널에서 `langswitch`만 입력하면 실행된다.

## 요구 사항

- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)
