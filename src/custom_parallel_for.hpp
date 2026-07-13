#ifndef PARALLEL_FOR_HPP
#define PARALLEL_FOR_HPP

#include <algorithm>
#include <atomic>
#include <cstddef>
#include <thread>
#include <vector>

/// Executes the given function for each index in the range [begin, end).
///
/// The work is distributed across several worker threads when threads are
/// enabled. In Emscripten builds without pthread support, it runs serially.
/// Returns immediately if the range is empty.
template <typename Index, typename Func>
void parallel_for(Index begin, Index end, Func fn) {
	const Index count = end - begin;
	if (count <= 0)
		return;

	// WebAssembly using Emscripten
	#if defined(__EMSCRIPTEN__) && !defined(__EMSCRIPTEN_PTHREADS__)
	for (Index i = begin; i < end; ++i)
		fn(i);
	#else
	unsigned int workers = std::thread::hardware_concurrency();
	if (workers == 0)
		workers = 4;

	// Avoid too many threads for small workloads.
	workers = std::min<unsigned int>(workers, static_cast<unsigned int>(count));

	std::atomic<Index> next{ begin };
	std::vector<std::thread> threads;
	threads.reserve(workers);

	for (unsigned int t = 0; t < workers; ++t) {
		threads.emplace_back([&]() {
			while (true) {
				Index i = next.fetch_add(1, std::memory_order_relaxed);
				if (i >= end)
					break;
				fn(i);
			}
		});
	}

	for (auto &thread : threads) {
		thread.join();
	}
	#endif
}

#endif
