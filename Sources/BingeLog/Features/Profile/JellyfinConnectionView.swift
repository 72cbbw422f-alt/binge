import SwiftUI

struct JellyfinConnectionView: View {
    @State private var serverAddress = SecureTokenStore.read(service: "BingeLog.Jellyfin.Server") ?? ""
    @State private var username = SecureTokenStore.read(service: "BingeLog.Jellyfin.Username") ?? ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var showDisconnectConfirmation = false

    private let service = JellyfinService()
    private var isConnected: Bool {
        SecureTokenStore.read(service: "BingeLog.Jellyfin.Token") != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ANSLUTNING")
                        .font(.caption.weight(.bold)).tracking(1.5)
                        .foregroundStyle(BingeTheme.accent)
                    Text("Jellyfin")
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Anslut till din egen Jellyfin-server. Inloggningsuppgifterna används bara för att skapa en personlig session.")
                        .font(.subheadline).foregroundStyle(BingeTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if isConnected {
                        Label("Ansluten", systemImage: "checkmark.circle.fill")
                            .font(.headline).foregroundStyle(BingeTheme.accent)
                        Text(SecureTokenStore.read(service: "BingeLog.Jellyfin.Server") ?? "")
                            .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                        Text("Inloggad som \(SecureTokenStore.read(service: "BingeLog.Jellyfin.Username") ?? "Jellyfin-användare")")
                            .font(.subheadline).foregroundStyle(.white)
                        Button("Koppla från Jellyfin", role: .destructive) {
                            showDisconnectConfirmation = true
                        }
                        .font(.footnote.weight(.semibold))
                    } else {
                        fieldLabel("SERVERADRESS")
                        TextField("https://jellyfin.dindomän.se:8096", text: $serverAddress)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.URL)
                            .padding(13)
                            .background(BingeTheme.elevated, in: RoundedRectangle(cornerRadius: 12))

                        fieldLabel("ANVÄNDARNAMN")
                        TextField("Jellyfin-användarnamn", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .padding(13)
                            .background(BingeTheme.elevated, in: RoundedRectangle(cornerRadius: 12))

                        fieldLabel("LÖSENORD")
                        SecureField("Jellyfin-lösenord", text: $password)
                            .textContentType(.password)
                            .padding(13)
                            .background(BingeTheme.elevated, in: RoundedRectangle(cornerRadius: 12))

                        Button {
                            Task { await connect() }
                        } label: {
                            HStack {
                                if isConnecting { ProgressView().tint(.black) }
                                Text(isConnecting ? "Ansluter…" : "Anslut till Jellyfin")
                                Spacer()
                                Image(systemName: "server.rack")
                            }
                            .font(.headline).foregroundStyle(.black).padding(15)
                            .background(BingeTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isConnecting || serverAddress.isEmpty || username.isEmpty || password.isEmpty)
                    }
                }
                .padding(16)
                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                }
                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(BingeTheme.accent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("OM DIN INTEGRATION")
                        .font(.caption.weight(.bold)).tracking(1.2)
                        .foregroundStyle(BingeTheme.secondaryText)
                    Text("Anslutningen använder Jellyfins MediaBrowser-autentisering. Serveradress, användarnamn och åtkomsttoken sparas i iOS-nyckelringen. Lösenordet sparas inte.")
                        .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                    Text("När anslutningen är klar kan du hämta biblioteket, matcha titlar som saknar TMDB-koppling och jämföra tittarstatus. Överföring till BingeLog sker först när du godkänner den.")
                        .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                }
                .padding(15)
                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Koppla från Jellyfin?", isPresented: $showDisconnectConfirmation, titleVisibility: .visible) {
            Button("Koppla från", role: .destructive) {
                Task {
                    await service.disconnect()
                    password = ""
                    statusMessage = "Jellyfin-sessionen har avslutats."
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Den sparade åtkomsttoken tas bort och sessionen avslutas på servern. Din BingeLog-samling påverkas inte.")
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(BingeTheme.secondaryText)
    }

    @MainActor
    private func connect() async {
        isConnecting = true
        errorMessage = nil
        statusMessage = nil
        defer { isConnecting = false }
        do {
            let result = try await service.authenticate(
                serverAddress: serverAddress,
                username: username,
                password: password
            )
            guard JellyfinService.saveConnection(server: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines), username: result.user.name, userID: result.user.id, token: result.accessToken) else {
                errorMessage = "Inloggningen lyckades men anslutningen kunde inte sparas i nyckelringen."
                return
            }
            username = result.user.name
            password = ""
            statusMessage = "Ansluten som \(result.user.name)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
