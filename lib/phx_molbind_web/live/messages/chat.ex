defmodule PhxMolbindWeb.Messages.Chat do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""
      <DefaultLayout>
      <div className="container mx-auto h-screen p-4">
        <h1 className="mb-6 text-3xl text-black dark:text-white">
          Drug Discovery Chat
        </h1>

        <div className="mb-6 flex flex-col space-y-4 sm:flex-row sm:space-x-4 sm:space-y-0">
          <input
            type="text"
            placeholder="Create new group"
            className="w-full rounded-lg border border-stroke bg-white p-4 outline-none focus:border-primary dark:border-form-strokedark dark:bg-form-input dark:text-white dark:focus:border-primary"
            onKeyPress={(e) => {
              if (e.key === "Enter") handleCreateGroup(e.target.value);
            }}
          />
          <div className="relative w-full">
            <select
              onChange={(e) => handleJoinGroup(e.target.value)}
              className="w-full rounded-lg border border-stroke bg-white p-4 outline-none focus:border-primary dark:border-form-strokedark dark:bg-form-input dark:text-white dark:focus:border-primary"
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
          <div className="rounded-lg border border-stroke p-6 dark:border-form-strokedark dark:bg-form-input">
            <h2 className="mb-4 text-xl text-black dark:text-white">
              Current Group: {currentGroup.name}
            </h2>
            <div className="dark:bg-gray-900 mb-4 h-64 overflow-y-auto rounded-lg bg-white p-4  dark:bg-[#181818]">
              {renderedMessages.length > 0 ? (
                <>
                  {renderedMessages}
                  <div ref={bottomRef}></div>
                </>
              ) : (
                <p className="text-gray-500">
                  No messages yet. Start chatting!
                </p>
              )}
            </div>
            <form onSubmit={handleFormSubmission} className="flex space-x-4">
              <input
                type="text"
                value={messageText}
                onChange={(e) => setMessageText(e.target.value)}
                placeholder="Type a message..."
                className="w-full rounded-lg border border-stroke bg-white p-4 outline-none focus:border-primary dark:border-form-strokedark dark:bg-form-input dark:text-white dark:focus:border-primary"
              />
              <button
                type="submit"
                disabled={!messageText.trim()}
                className="disabled:bg-gray-400 flex items-center justify-center rounded-lg bg-primary px-6 py-3 text-white transition hover:bg-opacity-90 disabled:cursor-not-allowed"
              >
                <SendIcon className="mr-2" />
                Send
              </button>
            </form>
          </div>
        )}
      </div>
    </DefaultLayout>
    """
  end

  def mount(params, session, socket) do
    {:ok, socket }
  end



end
