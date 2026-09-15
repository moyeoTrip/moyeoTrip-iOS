//
//  RecruitEditCourseSections.swift
//  MoyeoTrip
//
//  18-6 모집 내용 수정의 아래쪽 두 덩어리 — 연결된 코스(+18-7 로 가는 길)와 「모집을 그만두려면」.
//
//  `RecruitEditView` 가 파일 800줄·타입 300줄 제한에 걸려 여기로 나눴다. 화면 순서는 그대로다.
//

import SwiftUI

/// 잠긴 「연결된 코스」 줄 + 18-7 코스 이름·소개 수정 + 저장 안내 + 「모집을 그만두려면」 카드.
struct RecruitEditCourseAndCancelSections: View {
    /// 서버 방 상세의 코스 제목. 없으면 없다고 적는다 — 이름을 지어내지 않는다.
    let courseTitle: String?
    /// 직접 만든(`CUSTOM`) 코스인지. 아니면 18-7 버튼을 **그리지 않는다** (IOS-F131).
    let isCustomCourse: Bool
    let onEditCourseTitle: () -> Void
    let onOpenTripStatus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecruitEditLockedRow(
                label: "연결된 코스",
                value: courseTitle ?? "연결된 코스 없음",
                // 결정 ⑫ — 「여기서는 못 바꾼다」는 「다른 데서는 된다」로 읽혀 있지도 않은 화면을
                // 찾게 만든다. 서버 `UpdateChatRoomRequest` 에 `courseId` 가 없다 — 코스는 방을
                // 만들 때만 붙는다. 코스를 **교체**하는 것과 코스의 **내용을 고치는** 것은 다르므로
                // 방문지 순서를 고치는 길은 그대로 적어 둔다.
                hint: "모집을 만든 뒤에는 코스를 바꿀 수 없어요. 방문지 순서는 「여행 경로」에서 고쳐요.",
                isLocked: true
            )
            // 직접 만든 코스일 때만 그린다. 등록 코스 방에서는 눌러도 서버가 받지 않아
            // 「직접 만든 코스만, 여행 확정 전에 고칠 수 있어요.」 한 줄짜리 빈 화면만 열렸다 (IOS-F131).
            // 죽은 버튼을 두지 않되, 왜 없는지는 잠긴 「연결된 코스」 줄 아래에 적는다.
            if isCustomCourse {
                Button("코스 이름·소개 고치기", action: onEditCourseTitle)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MoyeoTheme.text700)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
                    .accessibilityIdentifier("recruitEdit.openCourseTitle")
                    .padding(.top, 10)
            } else {
                Text("등록된 코스를 그대로 쓰는 모임이라 코스 이름·소개는 고칠 수 없어요.")
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                    .accessibilityIdentifier("recruitEdit.courseTitleLocked")
            }

            AttachNoteBox(lines: [
                "저장하면 채팅방에 “호스트가 모집 정보를 수정했어요.”가 남고 참여자에게 알려요."
            ])

            // 방 삭제는 없다 — 취소로 갈음한다 (BE 회신 §4). 있는 길만 안내한다.
            VStack(alignment: .leading, spacing: 0) {
                Text("모집을 그만두려면")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(MoyeoTheme.ink)
                // 서버가 실제로 하는 일 그대로다(`ChatRoom.cancel`): 상태 CANCELLED · 채팅 잠금 ·
                // 14일 뒤 삭제 예약. 메시지는 바로 지워지지 않고 그동안 읽을 수 있다 (IOS-F128).
                Text(
                    "모집을 취소하면 참여자에게 알림이 가고, "
                        + "채팅방은 14일 동안 읽기 전용으로 유지된 후 사라져요."
                )
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
                // 안내만 있고 누를 곳이 없었다 — 웹 `nav.go('trip-status')` 와 같은 자리에 버튼을 둔다 (IOS-F129).
                Button("여행 확정 / 불발 처리하러 가기", action: onOpenTripStatus)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MoyeoTheme.dangerRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.dangerRed.opacity(0.5)))
                    .padding(.top, 11)
                    .accessibilityIdentifier("recruitEdit.openTripStatus")
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            .padding(.top, 22)
        }
    }
}
