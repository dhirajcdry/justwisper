import SwiftUI

/// First-run flow: walk through the two permissions + model download so the app
/// is fully ready before the user's first dictation.
struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private var ready: Bool { model.micGranted && model.accessibilityGranted && model.modelReady }

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "PRIVATE · ON-DEVICE", color: c.sig)
                    Text("Welcome to\nWisper.")
                        .font(F.extrabold(52)).tracking(-2).foregroundStyle(c.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Hold Right ⌥ and speak — your words are transcribed and polished entirely on this Mac, then dropped into whatever you're typing in. Nothing leaves the device.")
                        .font(F.regular(16)).foregroundStyle(c.ink2)
                        .frame(maxWidth: 480, alignment: .leading)
                }

                VStack(spacing: 0) {
                    step(index: "01", title: "Microphone",
                         subtitle: "So Wisper can hear you.",
                         done: model.micGranted, c: c) { model.requestMicrophone() }
                    EditorUI.divider(c)
                    step(index: "02", title: "Accessibility",
                         subtitle: "So it can paste into any app.",
                         done: model.accessibilityGranted, c: c) { model.refreshAccessibility(prompt: true) }
                    EditorUI.divider(c)
                    modelStep(c)
                    EditorUI.divider(c)
                    aiStep(c)
                }
                .padding(.horizontal, 18)
                .background(RoundedRectangle(cornerRadius: 10).fill(c.panel)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(c.line)))

                HStack(spacing: 16) {
                    Button { model.finishOnboarding() } label: {
                        HStack(spacing: 8) {
                            Text(ready ? "Start dictating" : "Continue anyway")
                                .font(F.semibold(15))
                            Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 9).fill(ready ? c.sig : c.ink))
                    }.buttonStyle(.plain)

                    if ready {
                        Text("You're all set.")
                            .font(F.mono(12)).tracking(0.6).foregroundStyle(c.ink3)
                    }
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 40)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(c.paper)
    }

    private func step(index: String, title: String, subtitle: String, done: Bool,
                      c: Palette, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Text(index).font(F.mono(13)).foregroundStyle(done ? c.sig : c.ink3).frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(F.semibold(16)).foregroundStyle(c.ink)
                Text(subtitle).font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
            }
            Spacer()
            if done { checkChip(c) } else { grantButton(c, action: action) }
        }
        .padding(.vertical, 16)
    }

    private func modelStep(_ c: Palette) -> some View {
        HStack(spacing: 16) {
            Text("03").font(F.mono(13)).foregroundStyle(model.modelReady ? c.sig : c.ink3).frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("Speech model").font(F.semibold(16)).foregroundStyle(c.ink)
                Text(ModelCatalog.info(model.modelName).name + " · downloads once, runs offline")
                    .font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
            }
            Spacer()
            if model.modelReady {
                checkChip(c)
            } else if let p = model.downloadProgress {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(c.sig)
                    Text("\(Int(p * 100))%").font(F.monoSemi(12)).foregroundStyle(c.sig)
                }
            } else {
                ProgressView().controlSize(.small).tint(c.sig)
            }
        }
        .padding(.vertical, 16)
    }

    private func aiStep(_ c: Palette) -> some View {
        HStack(spacing: 16) {
            Text("04").font(F.mono(13)).foregroundStyle(c.ink3).frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("AI polish").font(F.semibold(16)).foregroundStyle(c.ink)
                Text(model.aiStatus.blurb).font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
            }
            Spacer()
            let ok = model.aiStatus == .ready
            Text(ok ? "READY" : "OPTIONAL")
                .font(F.mono(10)).tracking(1).foregroundStyle(ok ? c.sig : c.ink3)
        }
        .padding(.vertical, 16)
    }

    private func checkChip(_ c: Palette) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
            Text("DONE").font(F.mono(10)).tracking(1)
        }
        .foregroundStyle(Color(hex: 0x28C840))
    }

    private func grantButton(_ c: Palette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("GRANT").font(F.monoSemi(11)).tracking(1).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 7).fill(c.sig))
        }.buttonStyle(.plain)
    }
}
