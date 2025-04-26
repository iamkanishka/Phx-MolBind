defmodule PhxMolbindWeb.MessagesLive.Chat do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""
      <%!-- <DefaultLayout>
      <div class="container mx-auto h-screen p-4">
        <h1 class="mb-6 text-3xl text-black dark:text-white">
          Drug Discovery Chat
        </h1>

        <div class="mb-6 flex flex-col space-y-4 sm:flex-row sm:space-x-4 sm:space-y-0">
          <input
            type="text"
            placeholder="Create new group"
            class="w-full rounded-lg border border-stroke bg-white p-4 outline-none focus:border-primary dark:border-form-strokedark dark:bg-form-input dark:text-white dark:focus:border-primary"
            onKeyPress={(e) => {
              if (e.key === "Enter") handleCreateGroup(e.target.value);
            }}
          />
          <div class="relative w-full">
            <select
              onChange={(e) => handleJoinGroup(e.target.value)}
              class="w-full rounded-lg border border-stroke bg-white p-4 outline-none focus:border-primary dark:border-form-strokedark dark:bg-form-input dark:text-white dark:focus:border-primary"
            >
              <option value="">Join a group</option>
              {groups.map((group) => (
                <option key={group._id} value={group._id}>
                  {group.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        {currentGroup && (
          <div class="rounded-lg border border-stroke p-6 dark:border-form-strokedark dark:bg-form-input">
            <h2 class="mb-4 text-xl text-black dark:text-white">
              Current Group: {currentGroup.name}
            </h2>
            <div class="dark:bg-gray-900 mb-4 h-64 overflow-y-auto rounded-lg bg-white p-4  dark:bg-[#181818]">
              {renderedMessages.length > 0 ? (
                <>
                  {renderedMessages}
                  <div ref={bottomRef}></div>
                </>
              ) : (
                <p class="text-gray-500">
                  No messages yet. Start chatting!
                </p>
              )}
            </div>
            <form onSubmit={handleFormSubmission} class="flex space-x-4">
              <input
                type="text"
                value={messageText}
                onChange={(e) => setMessageText(e.target.value)}
                placeholder="Type a message..."
                class="w-full rounded-lg border border-stroke bg-white p-4 outline-none focus:border-primary dark:border-form-strokedark dark:bg-form-input dark:text-white dark:focus:border-primary"
              />
              <button
                type="submit"
                disabled={!messageText.trim()}
                class="disabled:bg-gray-400 flex items-center justify-center rounded-lg bg-primary px-6 py-3 text-white transition hover:bg-opacity-90 disabled:cursor-not-allowed"
              >
                <SendIcon class="mr-2" />
                Send
              </button>
            </form>
          </div>
        )}
      </div>
    </DefaultLayout> --%>
    """
  end

  def  mount(_params, _session, socket) do
    {:ok, socket }
  end



end
