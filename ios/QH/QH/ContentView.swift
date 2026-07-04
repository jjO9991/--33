import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.purple)
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("契合")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("房屋租赁合同 AI 助手")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                VStack(spacing: 16) {
                    NavigationLink(destination: DraftFlowView()) {
                        Label("拟定合同", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: ReviewFlowView()) {
                        Label("审核合同", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Text("⚡ 平均 20 秒完成一份合同")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct HistoryView: View {
    var body: some View {
        NavigationView {
            List {
                Text("暂无历史记录")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("历史记录")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("0.1.0")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct ReviewFlowView: View {
    var body: some View {
        Text("审核合同工作区")
            .navigationTitle("审核合同")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
