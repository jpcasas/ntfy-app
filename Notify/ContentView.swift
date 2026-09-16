import SwiftUI
import Combine

extension View {
    func dismissKeyboardToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
    }
}

final class TopicsStore: ObservableObject {
    @Published var topics: [String] {
        didSet {
            UserDefaults.standard.set(topics, forKey: "ntfyTopics")
        }
    }

    init() {
        topics = UserDefaults.standard.stringArray(forKey: "ntfyTopics") ?? []
    }

    func add(_ topic: String) {
        let trimmed = topic.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !topics.contains(trimmed) else { return }
        topics.append(trimmed)
    }

    func remove(at offsets: IndexSet) {
        for index in offsets {
            MessageStore.shared.deleteTopic(topics[index])
        }
        topics.remove(atOffsets: offsets)
    }

    func remove(_ topic: String) {
        MessageStore.shared.deleteTopic(topic)
        topics.removeAll { $0 == topic }
    }
}

struct StoredMessage: Codable, Identifiable, Equatable {
    let id: String
    let topic: String
    let time: Int
    let title: String?
    let message: String?
    let priority: Int?
    let tags: [String]?
    var pinned: Bool = false

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(time))
    }

    init(from ntfy: NtfyMessage) {
        id = ntfy.id
        topic = ntfy.topic
        time = ntfy.time
        title = ntfy.title
        message = ntfy.message
        priority = ntfy.priority
        tags = ntfy.tags
        pinned = false
    }
}

final class MessageStore: ObservableObject {
    static let shared = MessageStore()

    @Published private(set) var byTopic: [String: [StoredMessage]] = [:]

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("messages.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: [StoredMessage]].self, from: data) else { return }
        byTopic = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(byTopic) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func messages(for topic: String) -> [StoredMessage] {
        (byTopic[topic] ?? []).sorted { $0.time > $1.time }
    }

    func lastMessageTime(for topic: String) -> Int? {
        byTopic[topic]?.map(\.time).max()
    }

    func ingest(_ ntfy: NtfyMessage) {
        var list = byTopic[ntfy.topic] ?? []
        guard !list.contains(where: { $0.id == ntfy.id }) else { return }
        list.append(StoredMessage(from: ntfy))
        byTopic[ntfy.topic] = list
        save()
    }

    func delete(topic: String, id: String) {
        byTopic[topic]?.removeAll { $0.id == id }
        save()
    }

    func togglePin(topic: String, id: String) {
        guard var list = byTopic[topic], let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].pinned.toggle()
        byTopic[topic] = list
        save()
    }

    func deleteTopic(_ topic: String) {
        byTopic.removeValue(forKey: topic)
        save()
    }

    var allPinned: [StoredMessage] {
        byTopic.values.flatMap { $0 }.filter { $0.pinned }.sorted { $0.time > $1.time }
    }
}

struct ContentView: View {
    @StateObject private var topicsStore = TopicsStore()

    var body: some View {
        TabView {
            TopicsView(topicsStore: topicsStore)
                .tabItem { Label("Topics", systemImage: "list.bullet") }

            SendView(topicsStore: topicsStore)
                .tabItem { Label("Enviar", systemImage: "paperplane") }

            PinnedView()
                .tabItem { Label("Fijados", systemImage: "pin.fill") }

            SettingsView()
                .tabItem { Label("Configuración", systemImage: "gearshape") }
        }
    }
}

struct TopicsView: View {
    @ObservedObject var topicsStore: TopicsStore
    @State private var path: [String] = []
    @State private var newTopic: String = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Nuevo topic") {
                    HStack {
                        TextField("Nombre del topic", text: $newTopic)
                            .autocapitalization(.none)
                        Button("Agregar") {
                            topicsStore.add(newTopic)
                            newTopic = ""
                        }
                        .disabled(newTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Mis topics") {
                    if topicsStore.topics.isEmpty {
                        Text("No tienes topics guardados")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(topicsStore.topics, id: \.self) { topic in
                            NavigationLink(value: topic) {
                                Text(topic)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Eliminar", role: .destructive) {
                                    topicsStore.remove(topic)
                                }
                            }
                        }
                        .onDelete(perform: topicsStore.remove)
                    }
                }
            }
            .navigationTitle("Topics")
            .navigationDestination(for: String.self) { topic in
                TopicDetailView(topic: topic, topicsStore: topicsStore)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardToolbar()
            .toolbar { EditButton() }
        }
    }
}

struct NtfyMessage: Codable, Identifiable {
    let id: String
    let time: Int
    let event: String
    let topic: String
    let title: String?
    let message: String?
    let priority: Int?
    let tags: [String]?

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(time))
    }
}

enum ConnectionState {
    case connecting
    case live
    case invalidServer
    case invalidURL
    case connectionError
    case disconnected(String)
}

struct ConnectionStatusView: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            switch state {
            case .connecting:
                ProgressView()
                    .controlSize(.mini)
                Text("Cargando historial...")
            case .live:
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundColor(.green)
                Text("En vivo")
            case .invalidServer:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Servidor inválido")
            case .invalidURL:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("URL inválida")
            case .connectionError:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error de conexión")
            case .disconnected(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(msg)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

struct TopicDetailView: View {
    let topic: String
    @ObservedObject var topicsStore: TopicsStore

    @AppStorage("ntfyServer") private var server: String = "https://ntfy.sh"
    @AppStorage("ntfyUsername") private var username: String = ""
    @AppStorage("ntfyPassword") private var password: String = ""

    @ObservedObject private var store = MessageStore.shared
    @State private var connectionState: ConnectionState = .connecting
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ConnectionStatusView(state: connectionState)
            }

            let messages = store.messages(for: topic)
            if messages.isEmpty {
                Text("Sin mensajes todavía")
                    .foregroundColor(.secondary)
            } else {
                ForEach(messages) { msg in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let title = msg.title, !title.isEmpty {
                                Text(title).font(.headline)
                            }
                            if msg.pinned {
                                Spacer()
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        Text(msg.message ?? "")
                            .font(.body)
                        Text(msg.date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Eliminar", role: .destructive) {
                            store.delete(topic: topic, id: msg.id)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button(msg.pinned ? "Desfijar" : "Fijar") {
                            store.togglePin(topic: topic, id: msg.id)
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle(topic)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog(
            "¿Eliminar este topic y su historial?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                topicsStore.remove(topic)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
        .task(id: topic) {
            await subscribe()
        }
    }

    func subscribe() async {
        guard var components = URLComponents(string: server.trimmingCharacters(in: .whitespaces)) else {
            connectionState = .invalidServer
            return
        }
        components.path = "/\(topic)/json"

        let since = store.lastMessageTime(for: topic).map { String($0) } ?? "all"
        components.queryItems = [URLQueryItem(name: "since", value: since)]

        guard let url = components.url else {
            connectionState = .invalidURL
            return
        }

        var request = URLRequest(url: url)
        if !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let credData = credentials.data(using: .utf8) {
                request.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        connectionState = .connecting

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                connectionState = .connectionError
                return
            }

            connectionState = .live

            for try await line in bytes.lines {
                guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                if let msg = try? JSONDecoder().decode(NtfyMessage.self, from: data), msg.event == "message" {
                    store.ingest(msg)
                }
            }
        } catch {
            if !Task.isCancelled {
                connectionState = .disconnected(error.localizedDescription)
            }
        }
    }
}

struct PinnedView: View {
    @ObservedObject private var store = MessageStore.shared

    var body: some View {
        NavigationStack {
            List {
                if store.allPinned.isEmpty {
                    Text("No tienes mensajes fijados")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.allPinned) { msg in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(msg.topic)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            if let title = msg.title, !title.isEmpty {
                                Text(title).font(.headline)
                            }
                            Text(msg.message ?? "")
                                .font(.body)
                            Text(msg.date, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Desfijar") {
                                store.togglePin(topic: msg.topic, id: msg.id)
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Fijados")
        }
    }
}

enum SendStatus {
    case success
    case error(String)
}

struct SendView: View {
    @ObservedObject var topicsStore: TopicsStore
    @AppStorage("ntfyServer") private var server: String = "https://ntfy.sh"
    @AppStorage("ntfyUsername") private var username: String = ""
    @AppStorage("ntfyPassword") private var password: String = ""

    @AppStorage("lastSelectedTopic") private var selectedTopic: String = ""
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var priority: Int = 3
    @State private var sendStatus: SendStatus?
    @State private var isSending: Bool = false

    let priorities = [1: "Mín", 2: "Baja", 3: "Normal", 4: "Alta", 5: "Urgente"]

    var body: some View {
        NavigationView {
            Form {
                Section("Topic") {
                    if topicsStore.topics.isEmpty {
                        Text("Agrega un topic en la pestaña Topics primero")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Topic", selection: $selectedTopic) {
                            ForEach(topicsStore.topics, id: \.self) { topic in
                                Text(topic).tag(topic)
                            }
                        }
                    }
                }

                Section("Mensaje") {
                    TextField("Título (opcional)", text: $title)
                    TextEditor(text: $message)
                        .frame(minHeight: 100)

                    Picker("Prioridad", selection: $priority) {
                        ForEach(priorities.sorted(by: { $0.key < $1.key }), id: \.key) { key, label in
                            Text(LocalizedStringKey(label)).tag(key)
                        }
                    }
                }

                Section {
                    Button(action: send) {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Enviar notificación")
                        }
                    }
                    .disabled(selectedTopic.isEmpty || message.isEmpty || isSending)
                }

                if let sendStatus {
                    Section {
                        switch sendStatus {
                        case .success:
                            Text("Enviado")
                                .foregroundColor(.green)
                        case .error(let detail):
                            Text("Error al enviar: \(detail)")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Enviar a ntfy")
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardToolbar()
            .onAppear {
                if selectedTopic.isEmpty {
                    selectedTopic = topicsStore.topics.first ?? ""
                }
            }
            .onChange(of: topicsStore.topics) { newTopics in
                if !newTopics.contains(selectedTopic) {
                    selectedTopic = newTopics.first ?? ""
                }
            }
        }
    }

    func send() {
        guard let base = URL(string: server.trimmingCharacters(in: .whitespaces)),
              !selectedTopic.isEmpty else { return }

        let url = base.appendingPathComponent(selectedTopic)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = message.data(using: .utf8)

        if !title.isEmpty {
            request.setValue(title, forHTTPHeaderField: "Title")
        }
        request.setValue(String(priority), forHTTPHeaderField: "Priority")

        if !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let credData = credentials.data(using: .utf8) {
                let base64 = credData.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        isSending = true
        sendStatus = nil

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isSending = false
                if let error = error {
                    sendStatus = .error(error.localizedDescription)
                } else if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    sendStatus = .success
                    message = ""
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    sendStatus = .error("HTTP \(code)")
                }
            }
        }.resume()
    }
}

struct SettingsView: View {
    @AppStorage("ntfyServer") private var server: String = "https://ntfy.sh"
    @AppStorage("ntfyUsername") private var username: String = ""
    @AppStorage("ntfyPassword") private var password: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Servidor") {
                    TextField("https://ntfy.sh", text: $server)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                Section("Autenticación") {
                    TextField("Usuario", text: $username)
                        .autocapitalization(.none)
                    SecureField("Contraseña", text: $password)
                }

                Section("Acerca de") {
                    LabeledContent("Versión", value: appVersionString)
                    LabeledContent("Desarrollador", value: "JP Casas")
                    Link("jpcasas@gmail.com", destination: URL(string: "mailto:jpcasas@gmail.com")!)
                }
            }
            .navigationTitle("Configuración")
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardToolbar()
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    ContentView()
}
